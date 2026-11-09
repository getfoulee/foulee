import SwiftUI

/// The screen's one main action, flat on the accent — "Démarrer ta sortie",
/// "Continuer", "Terminer l'installation".
struct PrimaryButton: View {
    var title: LocalizedStringResource
    var systemIcon: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemIcon {
                    Image(systemName: systemIcon)
                }
                Text(title)
            }
            .font(FouleeFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(FouleeColor.accent, in: .rect(cornerRadius: Radius.control))
        }
        .buttonStyle(.pressable)
    }
}

/// A quiet action beside the main one, on the raised neutral. Part of the
/// button pair shown in `DesignSystemGallery`; kept as the design-system
/// counterpart to `PrimaryButton`.
struct SecondaryButton: View {
    var title: LocalizedStringResource
    var systemIcon: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemIcon {
                    Image(systemName: systemIcon)
                }
                Text(title)
            }
            .font(FouleeFont.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(FouleeColor.raised, in: .rect(cornerRadius: Radius.control))
        }
        .buttonStyle(.pressable)
    }
}

/// Tap-feedback scaling — used by every Foulée button.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
