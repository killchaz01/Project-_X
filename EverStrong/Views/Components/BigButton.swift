import SwiftUI

/// A large, high-contrast button. Minimum 72pt tall: easy to hit with an unsteady hand.
struct BigButton: View {
    let title: String
    var symbol: String? = nil
    var color: Color = .accentColor
    var foreground: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let symbol {
                    Image(systemName: symbol).font(.title2.weight(.semibold))
                }
                Text(title).font(.title3.weight(.bold)).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 72)
            .foregroundStyle(foreground)
            .background(color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A rounded card used across the Today screen.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// A photo (or initials) in a circle, for family members.
struct ContactAvatar: View {
    let name: String
    let photoData: Data?
    var size: CGFloat = 120

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.accentColor.opacity(0.18)
                    Text(initials).font(.system(size: size * 0.38, weight: .bold)).foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

struct SafetyNote: View {
    let text: String
    var body: some View {
        Label {
            Text(text).font(.callout)
        } icon: {
            Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.orange)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

enum Disclaimers {
    static let exercise = "EverStrong gives general fitness guidance, not medical advice. Check with your doctor before starting a new exercise program. Stop if you feel pain, dizziness or shortness of breath."
    static let postpartum = "Only start postpartum exercise after your doctor or midwife has cleared you, usually at your 6-week check (often longer after a C-section). Stop and seek advice if you have pain, bleeding, leaking, heaviness, or doming down the middle of your tummy."
    static let medication = "Reminders help you remember. They do not replace advice from your doctor or pharmacist. Always follow your prescription."
    static let formCheck = "Form check is a helpful guide, not a replacement for a qualified coach or physiotherapist. Video stays on your iPhone and is never recorded."
    static let checkIn = "Check-ins are sent as text messages from your phone. EverStrong is not an emergency service. In an emergency, call your local emergency number."
}
