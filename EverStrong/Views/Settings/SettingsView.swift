import SwiftUI

struct SettingsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.largeText) private var largeText = false
    @AppStorage(AppSettings.spokenCoaching) private var spokenCoaching = true

    private var reminderTime: Binding<Date> {
        Binding(
            get: { TimeFormat.date(minuteOfDay: profile.workoutReminderHour * 60 + profile.workoutReminderMinute) },
            set: {
                let m = TimeFormat.minuteOfDay(from: $0)
                profile.workoutReminderHour = m / 60
                profile.workoutReminderMinute = m % 60
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Name", text: $profile.name).font(.title3)
                    Picker("Training for", selection: $profile.focus) {
                        ForEach(FitnessFocus.allCases) { Text($0.title).tag($0) }
                    }
                    .font(.title3)
                }

                Section("Easy to use") {
                    Toggle("Extra large text", isOn: $largeText).font(.title3)
                    Toggle("Spoken coaching", isOn: $spokenCoaching).font(.title3)
                }

                Section {
                    Toggle("Remind me to work out", isOn: $profile.workoutReminderEnabled).font(.title3)
                    if profile.workoutReminderEnabled {
                        DatePicker("Reminder time", selection: reminderTime, displayedComponents: .hourAndMinute)
                            .font(.title3)
                    }
                } header: {
                    Text("Daily reminder")
                }

                Section {
                    Toggle("My doctor or midwife has cleared me for postpartum exercise",
                           isOn: $profile.postpartumClearanceConfirmed)
                } header: {
                    Text("Postpartum")
                } footer: {
                    Text(Disclaimers.postpartum)
                }

                Section("Privacy") {
                    Text("Everything you enter stays on this iPhone. EverStrong has no account, no tracking and no ads. Form-check video is analysed live and never saved.")
                }

                Section("About") {
                    Text(Disclaimers.exercise).font(.footnote)
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.font(.title3.bold()) }
            }
            .onChange(of: profile.workoutReminderEnabled) { updateReminder() }
            .onChange(of: profile.workoutReminderHour) { updateReminder() }
            .onChange(of: profile.workoutReminderMinute) { updateReminder() }
        }
    }

    private func updateReminder() {
        if profile.workoutReminderEnabled {
            Task {
                guard await NotificationService.requestAuthorization() else { return }
                NotificationService.scheduleDailyWorkoutReminder(hour: profile.workoutReminderHour,
                                                                 minute: profile.workoutReminderMinute,
                                                                 name: profile.name)
            }
        } else {
            NotificationService.cancelDailyWorkoutReminder()
        }
    }
}
