import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: DriveSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Speed units", selection: $settings.useKPH) {
                        Text("MPH").tag(false)
                        Text("KM/H").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    volumeRow(title: "When parked", value: $settings.parkedVolume)
                    volumeRow(title: "At top speed", value: $settings.topVolume)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Top speed")
                            Spacer()
                            Text("\(Int(topSpeedDisplay.wrappedValue.rounded())) \(unitLabel)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: topSpeedDisplay, in: topSpeedRange, step: 1)
                    }
                } header: {
                    Text("Volume curve")
                } footer: {
                    Text("Volume climbs smoothly from the parked level to the top-speed level. Your iPhone has 16 volume clicks, so each click is about 6%.")
                }

                Section {
                    VolumeCurveGraph(settings: settings)
                        .frame(height: 140)
                        .padding(.vertical, 6)
                    VStack(spacing: 4) {
                        Slider(value: $settings.curveShape, in: -1...1, step: 0.05)
                        HStack {
                            Text("Slow start")
                            Spacer()
                            Text(curveShapeLabel)
                                .foregroundStyle(Theme.accent)
                            Spacer()
                            Text("Quick start")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Curve shape")
                } footer: {
                    Text("Quick start makes the music loud sooner in stop-and-go traffic, while still saving the top of the range for when you floor it. Slow start keeps it quieter around town and saves the big jump for the highway.")
                }

                Section("Preview") {
                    ForEach(previewSpeeds, id: \.self) { displaySpeed in
                        HStack {
                            Text("\(Int(displaySpeed)) \(unitLabel)")
                            Spacer()
                            Text("\(Int((previewVolume(atDisplaySpeed: displaySpeed) * 100).rounded()))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Toggle("Fewer volume pop-ups in other apps", isOn: $settings.calmInBackground)
                } footer: {
                    Text("iOS shows its volume pop-up whenever JamDrive changes the volume while you're in another app, like Maps. With this on, JamDrive waits until the volume needs to move by at least one click, and changes it at most every few seconds. In JamDrive itself, it always adjusts smoothly.")
                }

                Section {
                    Toggle("Show the car stereo tip when I start", isOn: $settings.showVolumeReminder)
                }

                Section {
                    Button("Reset volume curve to defaults", role: .destructive) {
                        settings.resetVolumeCurve()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    // MARK: Helpers

    private func volumeRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%  ·  \(Units.clicks(for: value.wrappedValue)) of \(Units.volumeClicks) clicks")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1, step: 0.01)
        }
    }

    private var curveShapeLabel: String {
        switch settings.curveShape {
        case ..<(-0.6): return "Much slower start"
        case ..<(-0.1): return "Slower start"
        case ...0.1: return "Straight line"
        case ...0.6: return "Quicker start"
        default: return "Much quicker start"
        }
    }

    private var unitFactor: Double { settings.useKPH ? Units.kphPerMph : 1 }
    private var unitLabel: String { settings.useKPH ? "km/h" : "mph" }

    /// The top speed shown in whichever unit is selected (it's always stored in mph).
    private var topSpeedDisplay: Binding<Double> {
        Binding(
            get: { settings.topSpeedMPH * unitFactor },
            set: { settings.topSpeedMPH = $0 / unitFactor }
        )
    }

    private var topSpeedRange: ClosedRange<Double> {
        let range = DriveSettings.topSpeedRangeMPH
        return (range.lowerBound * unitFactor).rounded()...(range.upperBound * unitFactor).rounded()
    }

    /// 0%, 25%, 50%, 75% and 100% of the top speed, in display units.
    private var previewSpeeds: [Double] {
        [0, 0.25, 0.5, 0.75, 1].map { (settings.topSpeedMPH * unitFactor * $0).rounded() }
    }

    private func previewVolume(atDisplaySpeed displaySpeed: Double) -> Double {
        let perMetersPerSecond = settings.useKPH ? Units.kphPerMetersPerSecond : Units.mphPerMetersPerSecond
        return settings.targetVolume(forSpeed: displaySpeed / perMetersPerSecond)
    }
}

/// A small chart of volume (up) against speed (across), so you can see what the curve slider does.
private struct VolumeCurveGraph: View {
    @ObservedObject var settings: DriveSettings

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                // Faint straight line for comparison.
                Path { path in
                    path.move(to: point(progress: 0, value: line(0), in: size))
                    path.addLine(to: point(progress: 1, value: line(1), in: size))
                }
                .stroke(Theme.dimText, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // The actual curve.
                Path { path in
                    let steps = 60
                    for i in 0...steps {
                        let p = Double(i) / Double(steps)
                        let value = settings.parkedVolume + (settings.topVolume - settings.parkedVolume) * settings.curved(p)
                        let pt = point(progress: p, value: value, in: size)
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                }
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                Text("Volume")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Speed →")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Volume curve graph")
    }

    private func line(_ p: Double) -> Double {
        settings.parkedVolume + (settings.topVolume - settings.parkedVolume) * p
    }

    private func point(progress: Double, value: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: progress * size.width, y: (1 - value) * size.height)
    }
}
