import SwiftUI
import SwiftData
import PhotosUI

struct FamilyView: View {
    let profile: UserProfile
    @Environment(\.openURL) private var openURL
    @Query(sort: \FamilyContact.sortOrder) private var family: [FamilyContact]
    @State private var adding = false
    @State private var editing: FamilyContact?
    @State private var showingCheckIn = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if family.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: "person.2.circle.fill").font(.system(size: 72)).foregroundStyle(Color.accentColor)
                            Text("Add your family").font(.title.bold())
                            Text("Add the people you call most. Their photo becomes a big button: one tap to call.")
                                .font(.title3)
                            BigButton(title: "Add a person", symbol: "person.badge.plus") { adding = true }
                        }
                    } else {
                        Text("Tap a photo to call").font(.title3).foregroundStyle(.secondary)
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(family) { person in
                                Button { call(person) } label: {
                                    VStack(spacing: 10) {
                                        ContactAvatar(name: person.name, photoData: person.photoData, size: 140)
                                        Text(person.name).font(.title3.bold()).foregroundStyle(.primary)
                                        if !person.relationship.isEmpty {
                                            Text(person.relationship).font(.body).foregroundStyle(.secondary)
                                        }
                                        Label("Call", systemImage: "phone.fill")
                                            .font(.headline)
                                            .padding(.horizontal, 20).padding(.vertical, 10)
                                            .foregroundStyle(.white)
                                            .background(Color.green, in: Capsule())
                                    }
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityLabel("Call \(person.name)")
                                .contextMenu {
                                    Button("Edit", systemImage: "pencil") { editing = person }
                                }
                            }
                        }
                        BigButton(title: "Send my “I'm OK” message", symbol: "hand.wave.fill", color: .green) {
                            showingCheckIn = true
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Family")
            .toolbar {
                if !family.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Add a person", systemImage: "person.badge.plus") { adding = true }
                            ForEach(family) { person in
                                Button("Edit \(person.name)", systemImage: "pencil") { editing = person }
                            }
                        } label: {
                            Text("Edit").font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $adding) { ContactEditor(contact: nil, nextSortOrder: family.count) }
            .sheet(item: $editing) { ContactEditor(contact: $0, nextSortOrder: family.count) }
            .sheet(isPresented: $showingCheckIn) { CheckInView(profile: profile) }
        }
    }

    private func call(_ person: FamilyContact) {
        guard !person.dialableNumber.isEmpty, let url = URL(string: "tel://\(person.dialableNumber)") else { return }
        openURL(url)
    }
}

struct ContactEditor: View {
    let contact: FamilyContact?
    let nextSortOrder: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var relationship = ""
    @State private var phone = ""
    @State private var receivesCheckIns = true
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var confirmDelete = false
    @State private var pickingContact = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { pickingContact = true } label: {
                        Label("Choose from my Contacts", systemImage: "person.crop.circle.badge.plus")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    }
                } footer: {
                    Text("Fills in their name, number and photo for you. Or type the details below.")
                }
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ContactAvatar(name: name.isEmpty ? "?" : name, photoData: photoData, size: 140)
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label(photoData == nil ? "Choose a photo" : "Change photo", systemImage: "photo")
                                    .font(.title3)
                            }
                        }
                        Spacer()
                    }
                }
                Section("Details") {
                    TextField("Name", text: $name).font(.title3).textContentType(.name)
                    TextField("Relationship, e.g. Daughter", text: $relationship).font(.title3)
                    TextField("Phone number", text: $phone).font(.title3)
                        .keyboardType(.phonePad).textContentType(.telephoneNumber)
                }
                Section {
                    Toggle("Send my daily “I'm OK” message", isOn: $receivesCheckIns).font(.title3)
                }
                if contact != nil {
                    Section {
                        Button("Remove person", role: .destructive) { confirmDelete = true }.font(.title3)
                    }
                }
            }
            .navigationTitle(contact == nil ? "Add a person" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.bold()
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || PhoneNumber.dialable(phone).isEmpty)
                }
            }
            .confirmationDialog("Remove this person?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let contact { context.delete(contact); try? context.save() }
                    dismiss()
                }
            }
            .background(
                ContactPickerPresenter(isPresented: $pickingContact) { picked in
                    name = picked.name
                    phone = picked.phone
                    if let data = picked.imageData { photoData = Self.downscaled(data) }
                }
            )
            .onAppear(perform: load)
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                    photoData = Self.downscaled(data)
                }
            }
        }
    }

    private func load() {
        guard let contact else { return }
        name = contact.name
        relationship = contact.relationship
        phone = contact.phone
        receivesCheckIns = contact.receivesCheckIns
        photoData = contact.photoData
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let contact {
            contact.name = trimmed
            contact.relationship = relationship
            contact.phone = phone
            contact.receivesCheckIns = receivesCheckIns
            contact.photoData = photoData
        } else {
            context.insert(FamilyContact(name: trimmed, relationship: relationship, phone: phone, photoData: photoData,
                                         receivesCheckIns: receivesCheckIns, sortOrder: nextSortOrder))
        }
        try? context.save()
        dismiss()
    }

    /// Keep photos small (max 600 px) so the app stays fast.
    private static func downscaled(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
