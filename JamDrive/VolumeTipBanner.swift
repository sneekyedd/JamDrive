import SwiftUI

/// The small notice that slides down from the top when a drive starts.
struct VolumeTipBanner: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text("Set your car stereo's volume")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Text("JamDrive controls your phone's volume and reaches its top level at top speed. Set the car stereo to the loudest you'd want to hear at that point.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08))
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
    }
}
