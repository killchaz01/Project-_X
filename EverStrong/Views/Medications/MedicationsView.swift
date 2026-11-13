import SwiftUI
import SwiftData

struct MedicationsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var editing: Medication?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                if medications.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: "pills.fill").font(.system(size: 56)).foregroundStyle(Color.accentColor)
                            Text("No medicines yet").font(.title2.bold())
                            Text("Add your medicines and EverStrong will remind you when it's time to take them.")
                                .font(.title3)
                            BigButton(title: "Add a medicine", symbol: "plus") { adding = true }
                        }
                        .padding(.vertical)
                    }
                }

                ForEach(medications) { med in
                    Section {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(med.name).font(.title2.bold())
                                if !med.dosage.isEmpty { Text(med.dosage).font(.title3) }
                            }
                            Spacer()
                            Button("Edit") { editing = med }.font(.title3).buttonStyle(.bordered)
                        }
                        ForEach(med.minutesOfDay, id: \.self) { minute in
                            DoseRow(medication: med, minute: minute)
                        }
                        if !med.notes.isEmpty {
                            Text(med.notes).font(.body).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text(Disclaimers.medication).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Medicines")
            .toolbar {
                if !medications.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { adding = true } label: { Label("Add", systemImage: "plus.circle.fill").font(.title2) }
                    }
                }
            }
            .sheet(isPresented: $adding) { MedicationEditor(medication: nil) }
            .sheet(item: $editing) { MedicationEditor(medication: $0) }
        }
    }
}

struct DoseRow: View {
    let medication: Medication
    let minute: Int
    @Environment(\.modelContext) private var context

    var body: some View {
        let taken = medication.isTaken(minute: minute)
        HStack {
            Image(systemName: taken ? "checkmark.circle.fill" : "clock")
                .font(.title2)
                .foregroundStyle(taken ? Color.green : Color.secondary)
            Text(TimeFormat.string(minuteOfDay: minute)).font(.title3)
            Spacer()
            if taken {
                Button("Undo") { undo() }.font(.body)
            } else {
                Button("Taken") { markTaken() }
                    .font(.title3.bold())
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(medication.name) at \(TimeFormat.string(minuteOfDay: minute)), \(taken ? "taken" : "not taken yet")")
    }

    private func markTaken() {
        context.insert(MedicationDose(scheduledMinute: minute, medication: medication))
        try? context.save()
    }

    private func undo() {
        for dose in medication.doses where dose.scheduledMinute == minute && Calendar.current.isDateInToday(dose.takenAt) {
            context.delete(dose)
        }
        try? context.save()
    }
}

struct MedicationEditor: View {
    let medication: Medication?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var dosage = ""
    @State private var notes = ""
    private struct TimeEntry: Identifiable { let id = UUID(); var date: Date }
    @State private var times: [TimeEntry] = [TimeEntry(date: TimeFormat.date(minuteOfDay: 8 * 60))]
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Medicine") {
                    TextField("Name, e.g. Metformin", text: $name).font(.title3)
                    TextField("Dose, e.g. 1 tablet, 500 mg", text: $dosage).font(.title3)
                }
                Section("Remind me at") {
                    ForEach($times) { $entry in
                        HStack {
                            DatePicker("Time", selection: $entry.date, displayedComponents: .hourAndMinute)
                                .font(.title3)
                            if times.count > 1 {
                                let id = entry.id
                                Button(role: .destructive) { times.removeAll { $0.id == id } } label: {
                                    Image(systemName: "minus.circle.fill").font(.title2)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove this time")
                            }
                        }
                    }
                    Button { times.append(TimeEntry(date: TimeFormat.date(minuteOfDay: 20 * 60))) } label: {
                        Label("Add another time", systemImage: "plus.circle.fill").font(.title3)
                    }
                }
                Section("Notes") {
                    TextField("e.g. Take with food", text: $notes, axis: .vertical).font(.title3)
                }
                if medication != nil {
                    Section {
                        Button("Delete medicine", role: .destructive) { confirmDelete = true }.font(.title3)
                    }
                }
            }
            .navigationTitle(medication == nil ? "Add medicine" : "Edit medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.bold().disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete this medicine and its reminders?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let medication else { return }
        name = medication.name
        dosage = medication.dosage
        notes = medication.notes
        times = medication.minutesOfDay.map { TimeEntry(date: TimeFormat.date(minuteOfDay: $0)) }
    }

    private func save() {
        let minutes = Array(Set(times.map { TimeFormat.minuteOfDay(from: $0.date) })).sorted()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let med: Medication
        var previous: [Int] = []
        if let medication {
            previous = medication.minutesOfDay
            medication.name = trimmedName
            medication.dosage = dosage
            medication.notes = notes
            medication.minutesOfDay = minutes
            med = medication
        } else {
            med = Medication(name: trimmedName, dosage: dosage, notes: notes, minutesOfDay: minutes)
            context.insert(med)
        }
        try? context.save()
        let id = med.id, n = med.name, d = med.dosage
        Task {
            await NotificationService.requestAuthorization()
            NotificationService.schedule(medicationID: id, name: n, dosage: d, minutes: minutes, previousMinutes: previous)
        }
        dismiss()
    }

    private func delete() {
        guard let medication else { return }
        NotificationService.cancel(medicationID: medication.id, minutes: medication.minutesOfDay)
        context.delete(medication)
        try? context.save()
        dismiss()
    }
}
