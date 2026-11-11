import CoreLocation

/// Wraps Apple's location service (`CLLocationManager`) and reports GPS readings.
/// Each reading includes the phone's current speed.
@MainActor
final class SpeedTracker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var onLocation: (@MainActor (CLLocation) -> Void)?
    var onAuthorizationChange: (@MainActor (CLAuthorizationStatus) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        // Don't let iOS pause updates at a red light; we need to know when you start moving again.
        manager.pausesLocationUpdatesAutomatically = false
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        // Keep receiving speed while another app (like Spotify) is on screen.
        // iOS shows a small blue location indicator while this is on.
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    // MARK: CLLocationManagerDelegate
    // iOS calls these on the main thread because the manager was created there.

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        MainActor.assumeIsolated {
            onLocation?(latest)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            onAuthorizationChange?(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Temporary GPS errors (tunnels, parking garages) are expected. We keep the last speed.
    }
}
