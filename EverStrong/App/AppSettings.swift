import SwiftUI

/// Keys for small per-device preferences stored with @AppStorage.
enum AppSettings {
    static let largeText = "settings.largeText"
    static let spokenCoaching = "settings.spokenCoaching"
    static let weeklyGoal = "settings.weeklyGoal"
}

extension View {
    /// When "Extra large text" is on, never let text drop below xxLarge,
    /// but still allow the system accessibility sizes above it.
    func everStrongTextSize(large: Bool) -> some View {
        Group {
            if large {
                self.dynamicTypeSize(.xxLarge ... .accessibility5)
            } else {
                self.dynamicTypeSize(.large ... .accessibility5)
            }
        }
    }
}
