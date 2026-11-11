import SwiftUI

/// The big round Start / Stop button.
struct PowerButton: View {
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.surface)
                Circle()
                    .strokeBorder(isOn ? Theme.accent : Color.white.opacity(0.14), lineWidth: 3)
                    .shadow(color: Theme.accent.opacity(isOn ? 0.7 : 0), radius: 14)
                VStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 34, weight: .semibold))
                    Text(isOn ? "STOP" : "START")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(3)
                }
                .foregroundStyle(isOn ? Theme.accent : Theme.primaryText)
            }
            .frame(width: 128, height: 128)
            .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: isOn)
        .animation(.easeInOut(duration: 0.25), value: isOn)
        .accessibilityLabel(isOn ? "Stop" : "Start")
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
