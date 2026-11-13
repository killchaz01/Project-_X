import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppSettings.largeText) private var largeText = false

    private enum Step: Int, CaseIterable { case welcome, name, focus, safety, reminders }
    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var focus: FitnessFocus = .over50
    @State private var acceptedSafety = false
    @State private var postpartumCleared = false

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
                .padding()
                .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch step {
                    case .welcome: welcome
                    case .name: nameStep
                    case .focus: focusStep
                    case .safety: safetyStep
                    case .reminders: remindersStep
                    }
                }
                .padding(24)
            }

            VStack(spacing: 12) {
                BigButton(title: primaryTitle, symbol: "arrow.right.circle.fill", color: canContinue ? .accentColor : .gray) {
                    advance()
                }
                .disabled(!canContinue)
                if step != .welcome {
                    Button("Back") { withAnimation { step = Step(rawValue: step.rawValue - 1) ?? .welcome } }
                        .font(.title3)
                        .frame(minHeight: 44)
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 96)).foregroundStyle(Color.accentColor)
            Text("Welcome to EverStrong").font(.largeTitle.bold())
            Text("Workouts made for you, reminders for your medicines, and an easy way to stay in touch with family.")
                .font(.title3)
            Toggle(isOn: $largeText) {
                Label("Extra large text", systemImage: "textformat.size").font(.title3)
            }
            .toggleStyle(.switch)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What should we call you?").font(.largeTitle.bold())
            TextField("Your first name", text: $name)
                .font(.title)
                .textContentType(.givenName)
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            Text("This is used to greet you and to sign your check-in messages to family.")
                .font(.body).foregroundStyle(.secondary)
        }
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What are you training for?").font(.largeTitle.bold())
            Text("You can change this at any time in Settings.").foregroundStyle(.secondary)
            ForEach(FitnessFocus.allCases) { option in
                FocusCard(focus: option, isSelected: option == focus) { focus = option }
            }
        }
    }

    private var safetyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your safety first").font(.largeTitle.bold())
            SafetyNote(text: Disclaimers.exercise)
            if focus == .postpartum {
                SafetyNote(text: Disclaimers.postpartum)
                Toggle("My doctor or midwife has cleared me to exercise", isOn: $postpartumCleared)
                    .font(.title3)
            }
            Toggle("I understand", isOn: $acceptedSafety).font(.title3.bold())
        }
    }

    private var remindersStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "bell.badge.fill").font(.system(size: 72)).foregroundStyle(Color.accentColor)
            Text("Turn on reminders").font(.largeTitle.bold())
            Text("EverStrong can remind you to take your medicines and to send your daily “I'm OK” message to family. On the next screen, tap **Allow**.")
                .font(.title3)
        }
    }

    // MARK: Navigation

    private var canContinue: Bool {
        switch step {
        case .name: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .safety: acceptedSafety
        default: true
        }
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: "Get started"
        case .reminders: "Allow reminders"
        default: "Continue"
        }
    }

    private func advance() {
        if step == .reminders {
            Task { await finish() }
        } else {
            withAnimation { step = Step(rawValue: step.rawValue + 1) ?? .reminders }
        }
    }

    private func finish() async {
        await NotificationService.requestAuthorization()
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let profile = UserProfile(name: trimmed, focus: focus)
        profile.postpartumClearanceConfirmed = postpartumCleared
        context.insert(profile)
        try? context.save()
        NotificationService.scheduleDailyCheckIn(hour: profile.checkInReminderHour,
                                                 minute: profile.checkInReminderMinute,
                                                 name: trimmed)
    }
}

struct FocusCard: View {
    let focus: FitnessFocus
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: focus.symbol)
                    .font(.largeTitle)
                    .frame(width: 56)
                    .foregroundStyle(isSelected ? .white : Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(focus.title).font(.title3.bold())
                    Text(focus.subtitle).font(.body).multilineTextAlignment(.leading)
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
            }
            .padding(18)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
