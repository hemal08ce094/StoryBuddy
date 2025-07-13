import UIKit

/// Centralized haptic feedback manager for the app.
struct HapticEngine {
    enum HapticEvent {
        case tap
        case heavyAction
        case success
        case warning
        case error
        case selection
        case seek
        case scrub
        case play
        case pause
        case voiceChange
        // Extend as needed for more granular events
    }

    static func play(_ event: HapticEvent) {
        switch event {
        case .tap:
            impact(.light)
        case .heavyAction, .play, .pause, .seek:
            impact(.heavy)
        case .scrub:
            impact(.medium)
        case .success:
            notification(.success)
        case .warning:
            notification(.warning)
        case .error:
            notification(.error)
        case .selection, .voiceChange:
            selection()
        }
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    private static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
