import Foundation

/// Unit conversions and other fixed numbers used around the app.
enum Units {
    /// GPS reports speed in meters per second; multiply by these to get mph or km/h.
    static let mphPerMetersPerSecond = 2.236936
    static let kphPerMetersPerSecond = 3.6
    static let kphPerMph = 1.609344

    /// An iPhone has 16 volume-button "clicks" from silent to max.
    static let volumeClicks = 16

    static func clicks(for volume: Double) -> Int {
        Int((volume * Double(volumeClicks)).rounded())
    }
}

/// The user's preferences. Every change is saved automatically, so they survive app restarts.
@MainActor
final class DriveSettings: ObservableObject {
    static let defaultParkedVolume = 0.25      // 4 of 16 clicks
    static let defaultTopVolume = 1.0          // all 16 clicks
    static let defaultTopSpeedMPH = 80.0
    static let topSpeedRangeMPH: ClosedRange<Double> = 20...120
    static let defaultCurveShape = 0.0         // straight line

    private enum Key {
        static let parkedVolume = "parkedVolume"
        static let topVolume = "topVolume"
        static let topSpeedMPH = "topSpeedMPH"
        static let useKPH = "useKPH"
        static let showVolumeReminder = "showVolumeReminder"
        static let curveShape = "curveShape"
        static let calmInBackground = "calmInBackground"
    }

    /// Volume (0...1) when the car is stopped.
    @Published var parkedVolume: Double {
        didSet {
            if topVolume < parkedVolume { topVolume = parkedVolume }
            defaults.set(parkedVolume, forKey: Key.parkedVolume)
        }
    }

    /// Volume (0...1) at or above the top speed.
    @Published var topVolume: Double {
        didSet {
            if parkedVolume > topVolume { parkedVolume = topVolume }
            defaults.set(topVolume, forKey: Key.topVolume)
        }
    }

    /// The speed (always stored in mph) at which volume reaches `topVolume`.
    @Published var topSpeedMPH: Double {
        didSet { defaults.set(topSpeedMPH, forKey: Key.topSpeedMPH) }
    }

    /// Bends the volume curve, from -1 to 1. 0 is a straight line.
    /// Above 0 ("quick start"): volume climbs fast at low speeds, then more slowly near top speed.
    /// Below 0 ("slow start"): volume stays low longer, then climbs fast near top speed.
    @Published var curveShape: Double {
        didSet { defaults.set(curveShape, forKey: Key.curveShape) }
    }

    /// While another app (like Maps) is on screen, change the volume in fewer, bigger steps,
    /// so the iOS volume pop-up doesn't keep appearing.
    @Published var calmInBackground: Bool {
        didSet { defaults.set(calmInBackground, forKey: Key.calmInBackground) }
    }

    /// Show km/h instead of mph.
    @Published var useKPH: Bool {
        didSet { defaults.set(useKPH, forKey: Key.useKPH) }
    }

    /// Show the "turn the volume all the way up" tip when a drive starts.
    @Published var showVolumeReminder: Bool {
        didSet { defaults.set(showVolumeReminder, forKey: Key.showVolumeReminder) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        parkedVolume = defaults.object(forKey: Key.parkedVolume) as? Double ?? DriveSettings.defaultParkedVolume
        topVolume = defaults.object(forKey: Key.topVolume) as? Double ?? DriveSettings.defaultTopVolume
        topSpeedMPH = defaults.object(forKey: Key.topSpeedMPH) as? Double ?? DriveSettings.defaultTopSpeedMPH
        useKPH = defaults.object(forKey: Key.useKPH) as? Bool ?? false
        showVolumeReminder = defaults.object(forKey: Key.showVolumeReminder) as? Bool ?? true
        curveShape = defaults.object(forKey: Key.curveShape) as? Double ?? DriveSettings.defaultCurveShape
        calmInBackground = defaults.object(forKey: Key.calmInBackground) as? Bool ?? false
    }

    /// The heart of the app: turns a speed into a volume.
    /// Parked → `parkedVolume`, top speed or faster → `topVolume`, and a curve in between.
    func targetVolume(forSpeed metersPerSecond: Double) -> Double {
        let mph = max(0, metersPerSecond) * Units.mphPerMetersPerSecond
        let progress = min(max(mph / topSpeedMPH, 0), 1)
        return parkedVolume + (topVolume - parkedVolume) * curved(progress)
    }

    /// Bends a 0...1 progress value according to `curveShape`. 0 and 1 always stay put,
    /// so parked and top-speed volumes are unchanged; only the middle moves.
    func curved(_ progress: Double) -> Double {
        // Shape +1 → power 0.4 (quick start), 0 → power 1 (straight), -1 → power 2.5 (slow start).
        let power = pow(2.5, -curveShape)
        return pow(progress, power)
    }

    func resetVolumeCurve() {
        topVolume = DriveSettings.defaultTopVolume
        parkedVolume = DriveSettings.defaultParkedVolume
        topSpeedMPH = DriveSettings.defaultTopSpeedMPH
        curveShape = DriveSettings.defaultCurveShape
    }
}
