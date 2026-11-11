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

    private enum Key {
        static let parkedVolume = "parkedVolume"
        static let topVolume = "topVolume"
        static let topSpeedMPH = "topSpeedMPH"
        static let useKPH = "useKPH"
        static let showVolumeReminder = "showVolumeReminder"
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
    }

    /// The heart of the app: turns a speed into a volume.
    /// Parked → `parkedVolume`, top speed or faster → `topVolume`, and a straight line in between.
    func targetVolume(forSpeed metersPerSecond: Double) -> Double {
        let mph = max(0, metersPerSecond) * Units.mphPerMetersPerSecond
        let progress = min(max(mph / topSpeedMPH, 0), 1)
        return parkedVolume + (topVolume - parkedVolume) * progress
    }

    func resetVolumeCurve() {
        topVolume = DriveSettings.defaultTopVolume
        parkedVolume = DriveSettings.defaultParkedVolume
        topSpeedMPH = DriveSettings.defaultTopSpeedMPH
    }
}
