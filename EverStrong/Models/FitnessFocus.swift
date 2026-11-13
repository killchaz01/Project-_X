import Foundation

/// What the person is mainly training for. Chosen during onboarding;
/// it decides which program is shown first on the Today and Workouts screens.
enum FitnessFocus: String, Codable, CaseIterable, Identifiable {
    case over50
    case postpartum
    case raceTraining
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .over50: "Strong Over 50"
        case .postpartum: "Postpartum Recovery"
        case .raceTraining: "Fitness Race Prep"
        case .general: "General Fitness"
        }
    }

    var subtitle: String {
        switch self {
        case .over50: "Gentle strength, balance and mobility to stay independent."
        case .postpartum: "Rebuild your core and pelvic floor safely after birth."
        case .raceTraining: "Running plus functional stations for hybrid fitness races."
        case .general: "Short, simple workouts to keep you moving."
        }
    }

    var symbol: String {
        switch self {
        case .over50: "figure.strengthtraining.functional"
        case .postpartum: "figure.and.child.holdinghands"
        case .raceTraining: "figure.run"
        case .general: "figure.mixed.cardio"
        }
    }
}
