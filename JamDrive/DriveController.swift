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

    // Fade tuning: how fast the volume follows changes in speed.
    private let tickInterval = 1.0 / 20.0     // update 20 times a second
    private let fadeTimeConstant = 0.8        // seconds to close most of the gap
    private let maxFadeRate = 0.35            // never move more than 35% of full volume per second

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

        // A negative speed means "unknown" for this reading. Keep the last one.
        guard location.speed >= 0 else { return }

        // GPS jitters a little while parked; treat anything under about 1 mph as stopped.
        let raw = location.speed < 0.5 ? 0 : location.speed
        // Light smoothing so one noisy reading doesn't jerk the volume around.
        var smoothed = speed + (raw - speed) * 0.6
        if smoothed < 0.05 { smoothed = 0 }
        speed = smoothed
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

        // Only touch the phone's volume when our number has actually moved. If you press the
        // volume buttons, JamDrive ignores it, and the next speed change sets its own level again.
        if abs(volume - lastAppliedVolume) >= 0.002 || (volume == target && volume != lastAppliedVolume) {
            SystemVolume.shared.set(volume)
            lastAppliedVolume = volume
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
