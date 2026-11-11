import SwiftUI

/// The main dashboard: speed, volume meter and the Start/Stop button.
struct ContentView: View {
    @EnvironmentObject private var controller: DriveController
    @EnvironmentObject private var settings: DriveSettings
    @Environment(\.openURL) private var openURL
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            // Invisible helper that lets JamDrive change the phone's volume. It must stay on screen.
            HiddenSystemVolumeView()
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                speedReadout
                Spacer(minLength: 12)
                volumeSection
                Spacer(minLength: 28)
                PowerButton(isOn: controller.isRunning) {
                    controller.toggle()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)

            if controller.showVolumeTip {
                VolumeTipBanner {
                    controller.dismissVolumeTip()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: controller.showVolumeTip)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
        .alert("Location access is off", isPresented: $controller.showLocationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("JamDrive needs your location to measure your speed. Turn it on in Settings → JamDrive → Location.")
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Text("JAMDRIVE")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var speedReadout: some View {
        VStack(spacing: 4) {
            Text(speedText)
                .font(.system(size: 140, weight: .thin, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(controller.isRunning ? Theme.primaryText : Theme.dimText)
                .contentTransition(.numericText())
                .animation(.snappy, value: speedText)

            // Tap the unit label to switch between mph and km/h.
            Button {
                settings.useKPH.toggle()
            } label: {
                Text(settings.useKPH ? "KM/H" : "MPH")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .accessibilityHint("Switches between miles and kilometers per hour")

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusText)
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.secondaryText)
            .padding(.top, 8)
        }
    }

    private var volumeSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("VOLUME")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(Int((controller.volume * 100).rounded()))%")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(controller.isRunning ? Theme.primaryText : Theme.dimText)
            }
            VolumeMeter(
                level: controller.volume,
                isActive: controller.isRunning,
                isMusicPlaying: controller.isMusicPlaying
            )
            .frame(height: 110)
        }
    }

    // MARK: Text helpers

    private var speedText: String {
        guard controller.isRunning else { return "0" }
        if controller.gpsState == .searching && controller.speed == 0 { return "--" }
        let factor = settings.useKPH ? Units.kphPerMetersPerSecond : Units.mphPerMetersPerSecond
        return String(Int((controller.speed * factor).rounded()))
    }

    private var statusText: String {
        switch controller.gpsState {
        case .off: return "Tap start before you drive"
        case .searching: return "Finding GPS…"
        case .locked: return "GPS locked"
        }
    }

    private var statusColor: Color {
        switch controller.gpsState {
        case .off: return Theme.dimText
        case .searching: return .orange
        case .locked: return Theme.accent
        }
    }
}
