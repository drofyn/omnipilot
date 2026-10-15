import Foundation
import Combine

enum SettingsTab: String, Hashable {
    case general
    case logs
    case about
}

/// Lightweight UI state shared between the menu bar panel and the settings window.
final class AppUIState: ObservableObject {
    static let shared = AppUIState()
    static let settingsWindowID = "settings"

    @Published var settingsTab: SettingsTab = .general

    private init() {}
}
