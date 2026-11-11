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
                    Toggle("Remind me to turn the volume up", isOn: $settings.showVolumeReminder)
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
