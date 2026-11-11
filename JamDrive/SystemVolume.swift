import AVFoundation
import MediaPlayer
import SwiftUI

/// Changes the iPhone's main volume, the same one the side buttons control.
///
/// iOS has no official API for this. The workaround: Apple's `MPVolumeView` contains a
/// volume slider, and moving that slider in code changes the volume for every app,
/// including Spotify. Keeping the view on screen (nearly invisible) also stops iOS from
/// showing its volume pop-up every time we adjust it.
@MainActor
final class SystemVolume {
    static let shared = SystemVolume()

    fileprivate weak var volumeView: MPVolumeView?

    private var slider: UISlider? {
        volumeView?.subviews.compactMap { $0 as? UISlider }.first
    }

    /// The phone's current volume, 0...1.
    var current: Double {
        Double(AVAudioSession.sharedInstance().outputVolume)
    }

    func set(_ volume: Double) {
        slider?.value = Float(min(max(volume, 0), 1))
    }
}

/// Put this somewhere in the view hierarchy so `SystemVolume` has a slider to move.
struct HiddenSystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        // Nearly invisible, but not fully hidden: a hidden view would bring back the iOS volume pop-up.
        view.alpha = 0.01
        view.isUserInteractionEnabled = false
        SystemVolume.shared.volumeView = view
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
