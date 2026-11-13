import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @AppStorage(AppSettings.largeText) private var largeText = false

    var body: some View {
        Group {
            if let profile = profiles.first {
                MainTabView(profile: profile)
            } else {
                OnboardingView()
            }
        }
        .everStrongTextSize(large: largeText)
    }
}

struct MainTabView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        TabView {
            TodayView(profile: profile)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            WorkoutsView(profile: profile)
                .tabItem { Label("Workouts", systemImage: "figure.strengthtraining.functional") }
            FormCheckView()
                .tabItem { Label("Form Check", systemImage: "camera.viewfinder") }
            NavigationStack { ProgressScreen() }
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
        }
    }
}
