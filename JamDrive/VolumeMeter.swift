import SwiftUI

/// The volume bar: 16 columns, one per iPhone volume click.
/// The number of lit columns shows the volume. While music plays, the lit columns
/// bounce like an equalizer.
///
/// Apple doesn't let one app read another app's audio, so the bounce is generated
/// animation, not Spotify's actual sound.
struct VolumeMeter: View {
    var level: Double          // 0...1
    var isActive: Bool         // a drive is running
    var isMusicPlaying: Bool

    static let segmentCount = Units.volumeClicks

    private var isDancing: Bool { isActive && isMusicPlaying }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isDancing)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let count = VolumeMeter.segmentCount
                let spacing: CGFloat = 5
                let width = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(0..<count, id: \.self) { index in
                        segment(index: index, width: width, maxHeight: geo.size.height, time: time)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int((level * 100).rounded())) percent")
    }

    private func segment(index: Int, width: CGFloat, maxHeight: CGFloat, time: TimeInterval) -> some View {
        // How much of this column is "on": 1 = fully lit, 0 = off, in between for the top column.
        let fill = min(max(level * Double(VolumeMeter.segmentCount) - Double(index), 0), 1)
        let color = VolumeMeter.color(for: index)
        let heightFraction = isDancing ? VolumeMeter.bounce(index: index, time: time) : 1.0
        let litHeight = max(width, maxHeight * CGFloat(heightFraction))
        let litOpacity = isActive ? 0.25 + 0.75 * fill : 0.35 * fill
        let corner = width / 3

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(height: maxHeight)
            if fill > 0 {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(color.opacity(litOpacity))
                    .frame(height: litHeight)
                    .shadow(color: color.opacity(isActive ? 0.55 * fill : 0), radius: 8)
            }
        }
        .frame(width: width, height: maxHeight, alignment: .bottom)
    }

    /// Teal → green → yellow → orange as the columns go up, like a car stereo's meter.
    static func color(for index: Int) -> Color {
        let t = Double(index) / Double(segmentCount - 1)
        return Color(hue: 0.48 - 0.43 * t, saturation: 0.85, brightness: 1.0)
    }

    /// A made-up but musical-looking bounce: a steady "kick drum" pulse (strongest on the
    /// left, bass-side columns) mixed with a few overlapping waves.
    static func bounce(index: Int, time: TimeInterval) -> Double {
        let i = Double(index)
        let kick = pow(max(0, sin(time * Double.pi * 4.0)), 6)   // 2 pulses/sec ≈ 120 BPM
        let bassWeight = max(0, 1 - i / 6)
        let waveA = 0.5 + 0.5 * sin(time * (2.3 + i * 0.37) + i * 1.9)
        let waveB = 0.5 + 0.5 * sin(time * (4.1 + i.truncatingRemainder(dividingBy: 5) * 0.9) + i * 0.7)
        let value = 0.22 + 0.5 * waveA * waveB + 0.4 * kick * (0.35 + 0.65 * bassWeight)
        return min(max(value, 0.12), 1)
    }
}
