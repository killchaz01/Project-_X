import SwiftUI
import SwiftData
import MessageUI

/// The daily "I'm OK" check-in. Saves the check-in and opens a pre-written text to family.
struct CheckInView: View {
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FamilyContact.sortOrder) private var family: [FamilyContact]

    @State private var composer: ComposerRequest?
    @State private var resultMessage: String?

    private var recipients: [String] {
        family.filter(\.receivesCheckIns).map(\.dialableNumber).filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How are you today?").font(.largeTitle.bold())

                    if recipients.isEmpty {
                        SafetyNote(text: "No family members are set to receive check-ins yet. Add them on the Family tab. Your check-in will still be saved.")
                    } else {
                        Text("We'll write a message to \(family.filter(\.receivesCheckIns).map(\.name).formatted(.list(type: .and))). You just tap Send.")
                            .font(.title3)
                    }

                    BigButton(title: "I'm OK today", symbol: "hand.thumbsup.fill", color: .green) {
                        send(status: "ok", text: "Hi, it's \(profile.name). Just checking in. I'm OK today. 💛")
                    }
                    BigButton(title: "Please call me", symbol: "phone.arrow.up.right.fill", color: .orange) {
                        send(status: "needsCall", text: "Hi, it's \(profile.name). I'm safe, but could you give me a call when you can? 📞")
                    }

                    if let resultMessage {
                        Label(resultMessage, systemImage: "checkmark.circle.fill")
                            .font(.title3).foregroundStyle(.green)
                    }

                    Text(Disclaimers.checkIn).font(.footnote).foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.font(.title3) }
            }
            .sheet(item: $composer) { request in
                MessageComposer(recipients: request.recipients, body: request.body) { sent in
                    composer = nil
                    resultMessage = sent ? "Message sent. Thank you!" : "Check-in saved. The message wasn't sent."
                }
                .ignoresSafeArea()
            }
        }
    }

    private func send(status: String, text: String) {
        context.insert(CheckIn(status: status))
        try? context.save()
        if !recipients.isEmpty && MFMessageComposeViewController.canSendText() {
            composer = ComposerRequest(recipients: recipients, body: text)
        } else {
            resultMessage = recipients.isEmpty ? "Check-in saved." : "Check-in saved. This device can't send text messages."
        }
    }
}

struct ComposerRequest: Identifiable {
    let id = UUID()
    let recipients: [String]
    let body: String
}

struct MessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            onFinish(result == .sent)
        }
    }
}
