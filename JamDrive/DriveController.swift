import AVFoundation
import CoreLocation
import UIKit

/// Runs a drive: reads GPS speed, works out the target volume, and fades the phone's volume toward it.
@MainActor
final class DriveController: ObservableObject {
    enum GPSState {
        case off, searching, locked
    }

    @Published private(set) var isRunning = false
    /// Smoothed speed in meters per second.
    @Published private(set) var speed: Double = 0
    @Published private(set) var gpsState: GPSState = .off
    /// The volume JamDrive is currently applying, 0...1.
    @Published private(set) var volume: Double
    @Published private(set) var isMusicPlaying = false
    /// False when iOS's "Precise Location" switch is off for JamDrive.
    @Published private(set) var hasPreciseLocation = true
    @Published var showVolumeTip = false
    @Published var showLocationDeniedAlert = false

    let settings: DriveSettings

    private let tracker = SpeedTracker()
    private var timer: Timer?
    private var tickCount = 0
    private var lastAppliedVolume: Double = -1
    private var lastFixDate: Date?
    private var startWhenAuthorized = false
    private var tipTask: Task<Void, Never>?

    // GPS only reports about once a second. Between readings we estimate the speed from
    // how quickly it was changing (acceleration), so the speed and volume move smoothly
    // and keep up with you instead of jumping a second late.
    private var gpsSpeed: Double = 0              // last measured speed, m/s
    private var gpsSpeedDate: Date?
    private var acceleration: Double = 0          // m/s per second; negative when braking
    private var lastLocation: CLLocation?
    private let maxPredictAhead = 1.2             // never guess more than 1.2 s past the last reading
    private let maxAcceleration = 6.0             // about 0.6 g; anything bigger is GPS noise

    // Fade tuning: how fast the volume follows changes in speed.
    // Hard acceleration or braking moves the target quickly, so the volume moves quickly too.
    private let tickInterval = 1.0 / 20.0     // update 20 times a second
    private let fadeTimeConstant = 0.25       // seconds to close most of the gap
    private let maxFadeRate = 1.5             // safety cap: at most 150% of full volume per second

    // "Fewer pop-ups" mode, used while another app is on screen.
    private let oneClick = 1.0 / Double(Units.volumeClicks)   // about 6%
    private let calmMinInterval = 3.0                         // seconds between changes
    private var lastApplyDate: Date?

    init(settings: DriveSettings) {
        self.settings = settings
        self.volume = settings.parkedVolume
        tracker.onLocation = { [weak self] location in
            self?.handle(location)
        }
        tracker.onAuthorizationChange = { [weak self] status in
            self?.handleAuthorization(status)
        }
    }

    // MARK: Start / stop

    func toggle() {
        if isRunning { stop() } else { start() }
    }

    func start() {
        guard !isRunning else { return }
        switch tracker.authorizationStatus {
        case .notDetermined:
            startWhenAuthorized = true
            tracker.requestPermission()
        case .denied, .restricted:
            showLocationDeniedAlert = true
        default:
            beginDrive()
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        tracker.stop()
        timer?.invalidate()
        timer = nil
        gpsState = .off
        speed = 0
        isMusicPlaying = false
        UIApplication.shared.isIdleTimerDisabled = false
        dismissVolumeTip()
        // The phone's volume is left wherever it was when you pressed Stop.
    }

    private func beginDrive() {
        isRunning = true
        gpsState = .searching
        speed = 0
        lastFixDate = nil
        tickCount = 0
        gpsSpeed = 0
        gpsSpeedDate = nil
        acceleration = 0
        lastLocation = nil
        hasPreciseLocation = tracker.hasPreciseLocation

        activateAudioSession()
        // Fade from wherever the phone's volume is right now.
        volume = SystemVolume.shared.current
        lastAppliedVolume = volume
        isMusicPlaying = AVAudioSession.sharedInstance().isOtherAudioPlaying

        tracker.start()
        startTimer()
        // Keep the screen awake so it works as a dashboard display.
        UIApplication.shared.isIdleTimerDisabled = true

        if settings.showVolumeReminder {
            presentVolumeTip()
        }
    }

    /// A quiet "ambient" audio session lets us read the phone's volume and see whether
    /// Spotify is playing, without pausing or ducking Spotify.
    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    // MARK: GPS

    private func handle(_ location: CLLocation) {
        guard isRunning else { return }
        // Ignore old cached readings and readings without a real position.
        guard abs(location.timestamp.timeIntervalSinceNow) < 10, location.horizontalAccuracy >= 0 else { return }

        lastFixDate = Date()
        gpsState = .locked
        hasPreciseLocation = tracker.hasPreciseLocation

        let previous = lastLocation
        lastLocation = location

        // iOS's own speed reading (from the GPS signal's Doppler shift) is the most accurate.
        // If it's missing or unreliable, work it out from the distance since the last reading.
        var measured: Double?
        if location.speed >= 0, location.speedAccuracy < 0 || location.speedAccuracy <= 3 {
            measured = location.speed
        } else if let previous {
            let dt = location.timestamp.timeIntervalSince(previous.timestamp)
            if dt > 0.2, dt < 3, location.horizontalAccuracy < 20 {
                measured = location.distance(from: previous) / dt
            }
        }
        guard var raw = measured else { return }

        // GPS jitters a little while parked; treat anything under about 1 mph as stopped.
        if raw < 0.5 { raw = 0 }

        let now = location.timestamp
        if let lastDate = gpsSpeedDate {
            let dt = now.timeIntervalSince(lastDate)
            if dt > 0.2 {
                let newAccel = min(max((raw - gpsSpeed) / dt, -maxAcceleration), maxAcceleration)
                // Blend with the previous value so one odd reading doesn't throw it off.
                acceleration = acceleration * 0.4 + newAccel * 0.6
            }
        }
        if raw == 0 { acceleration = 0 }
        gpsSpeed = raw
        gpsSpeedDate = now
    }

    /// Our best guess at the speed right now: the last GPS reading, plus however much
    /// the speed has probably changed since, based on the recent acceleration.
    private func estimatedSpeed() -> Double {
        guard let gpsSpeedDate else { return gpsSpeed }
        let elapsed = min(max(Date().timeIntervalSince(gpsSpeedDate), 0), maxPredictAhead)
        let estimate = gpsSpeed + acceleration * elapsed
        return estimate < 0.3 ? 0 : estimate
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if startWhenAuthorized {
                startWhenAuthorized = false
                beginDrive()
            }
        case .denied, .restricted:
            if startWhenAuthorized {
                startWhenAuthorized = false
                showLocationDeniedAlert = true
            }
            stop()
        default:
            break
        }
    }

    // MARK: Volume fading

    private func startTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.step()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    /// Runs 20 times a second: nudges the volume a little toward the target.
    private func step() {
        let estimate = estimatedSpeed()
        if abs(estimate - speed) > 0.01 { speed = estimate }

        let target = settings.targetVolume(forSpeed: speed)
        let gap = target - volume

        var newVolume: Double
        if abs(gap) < 0.001 {
            newVolume = target
        } else {
            let maxStep = maxFadeRate * tickInterval
            let easedStep = gap * min(1, tickInterval / fadeTimeConstant)
            newVolume = volume + min(max(easedStep, -maxStep), maxStep)
        }
        newVolume = min(max(newVolume, 0), 1)
        if newVolume != volume {
            volume = newVolume
        }

        let inOtherApp = UIApplication.shared.applicationState != .active
        if inOtherApp && settings.calmInBackground {
            // iOS shows its volume pop-up for every change made while another app is on screen.
            // So wait until the target is at least one volume click away, then jump straight
            // to it in one go, and don't do that more often than every few seconds.
            let sinceLastApply = lastApplyDate.map { Date().timeIntervalSince($0) } ?? .infinity
            if abs(target - lastAppliedVolume) >= oneClick, sinceLastApply >= calmMinInterval {
                volume = target
                applyVolume(target)
            }
        } else if abs(volume - lastAppliedVolume) >= 0.002 || (volume == target && volume != lastAppliedVolume) {
            // Only touch the phone's volume when our number has actually moved. If you press the
            // volume buttons, JamDrive ignores it, and the next speed change sets its own level again.
            applyVolume(volume)
        }

        // Once a second: check whether music is playing and whether GPS has gone quiet.
        tickCount += 1
        if tickCount % 20 == 0 {
            let playing = AVAudioSession.sharedInstance().isOtherAudioPlaying
            if playing != isMusicPlaying { isMusicPlaying = playing }
            if let lastFixDate, Date().timeIntervalSince(lastFixDate) > 5, gpsState != .searching {
                gpsState = .searching
            }
        }
    }

    private func applyVolume(_ value: Double) {
        SystemVolume.shared.set(value)
        lastAppliedVolume = value
        lastApplyDate = Date()
    }

    // MARK: Volume tip banner

    private func presentVolumeTip() {
        showVolumeTip = true
        tipTask?.cancel()
        tipTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.showVolumeTip = false
        }
    }

    func dismissVolumeTip() {
        tipTask?.cancel()
        tipTask = nil
        showVolumeTip = false
    }
}
