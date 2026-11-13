import SwiftUI
import ContactsUI

/// The details we copy from a contact the user picks.
struct PickedContact {
    let name: String
    let phone: String
    let imageData: Data?

    init(name: String, phone: String, imageData: Data?) {
        self.name = name
        self.phone = phone
        self.imageData = imageData
    }

    init(_ contact: CNContact) {
        let full = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        self.name = contact.givenName.isEmpty ? full : contact.givenName
        self.phone = Self.preferredNumber(contact.phoneNumbers.map { (label: $0.label, number: $0.value.stringValue) })
        self.imageData = contact.imageDataAvailable ? (contact.thumbnailImageData ?? contact.imageData) : nil
    }

    /// Prefer a mobile number (best for calls and texts), otherwise the first one.
    static func preferredNumber(_ numbers: [(label: String?, number: String)]) -> String {
        let mobileLabels: Set<String> = [CNLabelPhoneNumberMobile, CNLabelPhoneNumberiPhone]
        if let mobile = numbers.first(where: { entry in entry.label.map { mobileLabels.contains($0) } ?? false }) {
            return mobile.number
        }
        return numbers.first?.number ?? ""
    }
}

/// Presents Apple's contact picker. It runs outside the app's process, so no Contacts permission is needed:
/// the app only ever sees the one person the user chooses.
///
/// Used as an invisible `.background(...)`; the picker is presented from a hosting view controller,
/// which avoids the blank-screen problems of putting the picker directly inside a SwiftUI sheet.
struct ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (PickedContact) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil, host.view.window != nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Only offer people who have a phone number.
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        host.present(picker, animated: true)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerPresenter
        init(_ parent: ContactPickerPresenter) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.isPresented = false
            parent.onPick(PickedContact(contact))
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}
