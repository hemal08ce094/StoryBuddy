//
//  StoryGenerator.swift
//  Story Buddy
//
//  Created by hemal on 22/06/2025.
//
//  Note:
//  - Story models (SavedStory, StoryGenerationParameters) have been moved to StoryModels.swift
//  - Persistence logic for saved stories is handled via UserDefaults extension
//

import Foundation
import FoundationModels

@MainActor
class StoryGenerator {
    static let shared = StoryGenerator()

    private var session: LanguageModelSession?

    init() {

    }

    private let safetyRetryPrefix = "Safety note: This is for young children. Avoid scary, violent, or unsafe themes. Keep everything gentle, positive, and age-appropriate."

    private func respondWithSafetyRetry<T>(
        _ session: LanguageModelSession,
        prompt: String,
        generating type: T.Type
    ) async throws -> LanguageModelSession.Response<T> where T: Generable {
        do {
            return try await session.respond(to: prompt, generating: type)
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error {
                let retryPrompt = safetyRetryPrefix + "\n" + prompt
                return try await session.respond(to: retryPrompt, generating: type)
            }
            throw error
        }
    }

    private func respondWithSafetyRetry(
        _ session: LanguageModelSession,
        prompt: String
    ) async throws -> LanguageModelSession.Response<String> {
        do {
            return try await session.respond(to: prompt)
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error {
                let retryPrompt = safetyRetryPrefix + "\n" + prompt
                return try await session.respond(to: retryPrompt)
            }
            throw error
        }
    }

    /// Recommended for story playback, this version generates a kid-friendly story that is more readable for children.
    /// Generates a kid-friendly story based on the provided parameters, streaming updates during creation.
    /// Returns the fully saved story for use in playback views.
    /// Callers should await the result and use the `SavedStory`'s `content` for playback.
    func generateKidFriendlyStory(with parameters: StoryGenerationParameters, onUpdate: @escaping (String, Bool) -> Void, onDNAGenerated: ((StoryDNA) -> Void)? = nil) async throws -> SavedStory {
        let session = LanguageModelSession()
        
        // Generate unique story DNA to avoid repetition
        let recentStories = savedStories().prefix(10).map { $0 }
        let storyDNA = try await StoryUniquenessEngine.shared.generateUniqueDNA(
            for: parameters.topic,
            avoidSimilarTo: Array(recentStories)
        )
        
        // Notify caller about DNA
        onDNAGenerated?(storyDNA)
        
        // Build enhanced prompt with uniqueness
        let composedPrompt = StoryUniquenessEngine.shared.buildEnhancedPrompt(
            baseTopic: parameters.topic,
            dna: storyDNA,
            parameters: parameters
        )

        // Generate story outline
        let outlineResponse = try await respondWithSafetyRetry(
            session,
            prompt: "Create an outline for a children's story: \(composedPrompt)",
            generating: StoryOutline.self
        )
        let outline = outlineResponse.content
        let title = outline.title

        // Get kid-appropriate section titles
        let sectionsResponse = try await respondWithSafetyRetry(
            session,
            prompt: "Based on the outline for the children's story '\(title)',  fun,kid-appropriate. Only return the array, nothing else."
        )
        let sectionTitles: [String]
        if let data = sectionsResponse.content.data(using: String.Encoding.utf8), let parsed = try? JSONDecoder().decode([String].self, from: data) {
            sectionTitles = parsed
        } else {
            sectionTitles = sectionsResponse.content
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        var partialStory = "\n🏷️ Title: \(title)\n"
        onUpdate(partialStory, false)

        for (idx, section) in sectionTitles.enumerated() {
            let storySection = try await respondWithSafetyRetry(
                session,
                prompt: "Write Section \(idx + 1): '\(section)' for the children's story '\(title)'. Use 1-2 short, simple paragraphs. Be concrete, friendly, and advance the plot, focusing on clear actions."
            )
//            partialStory += "\n\nSection \(idx + 1): \(section)\n" + storySection.content
            partialStory += storySection.content
            
            let isFinished = idx == sectionTitles.count - 1
            onUpdate(partialStory, isFinished)
        }

        let highLevelDescription: String = {
            let protagonist = outline.protagonist
            let conflict = outline.conflict
            let setting = outline.setting
            let genre = String(describing: outline.genre)
            let themes = outline.themes.joined(separator: ", ")
            return "A \(genre) story for kids set in \(setting), following \(protagonist) as they face: \(conflict). Themes: \(themes)."
        }()

        let saved = SavedStory(
            id: UUID().uuidString,
            title: title,
            description: highLevelDescription,
            content: partialStory,
            date: Date(),
            duration: parameters.duration,
            type: parameters.topic,
            kidNames: parameters.kidNames
        )
        self.saveStory(saved)
        return saved
    }

    // MARK: - Story Persistence

    /// Returns all saved stories sorted by most recent.
    func savedStories() -> [SavedStory] {
        UserDefaults.standard.loadStories().sorted { $0.date > $1.date }
    }

    /// Returns the saved story matching the given ID.
    func story(withID id: String) -> SavedStory? {
        UserDefaults.standard.loadStories().first { $0.id == id }
    }

    /// Saves the given story, replacing any existing story with the same ID.
    /// Ensures no duplicates and persistent storage.
    private func saveStory(_ story: SavedStory) {
        var stories = UserDefaults.standard.loadStories()
        stories.removeAll(where: { $0.id == story.id })
        stories.append(story)
        UserDefaults.standard.saveStories(stories)
    }
}


