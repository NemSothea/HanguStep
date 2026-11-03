import Domain
import DesignSystem
import Foundation
import Observation

/// Settings shared across screens. Loaded once at startup, written through `SaveSettings`.
@MainActor
@Observable
public final class LearnerPreferences {
    public private(set) var settings: LearnerSettings
    private let save: any SaveSettingsUseCase

    public init(settings: LearnerSettings, save: any SaveSettingsUseCase) {
        self.settings = settings
        self.save = save
    }

    public var glossLanguage: GlossLanguage { settings.glossLanguage }

    public func update(_ change: (inout LearnerSettings) -> Void) async throws {
        var updated = settings
        change(&updated)
        settings = try await save.execute(updated)
    }

    /// Primary and secondary lines for a gloss in the learner's preferred order.
    public func lines(for gloss: Gloss) -> (primary: GlossText.Line, secondary: GlossText.Line) {
        switch settings.glossLanguage {
        case .english: return (.english(gloss.english), .khmer(gloss.khmer))
        case .khmer: return (.khmer(gloss.khmer), .english(gloss.english))
        }
    }
}

/// Convenience for views: `GlossText` driven by preferences.
import SwiftUI

struct PreferredGlossText: View {
    @Environment(LearnerPreferences.self) private var preferences
    let gloss: Gloss
    var showSecondary = true

    var body: some View {
        let lines = preferences.lines(for: gloss)
        GlossText(primary: lines.primary, secondary: showSecondary ? lines.secondary : nil)
    }
}
