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

    /// Recommended for story playback, this version generates a kid-friendly story that is more readable for children.
    /// Generates a kid-friendly story based on the provided parameters, streaming updates during creation.
    /// Returns the fully saved story for use in playback views.
    /// Callers should await the result and use the `SavedStory`'s `content` for playback.
    func generateKidFriendlyStory(with parameters: StoryGenerationParameters, onUpdate: @escaping (String, Bool) -> Void) async throws -> SavedStory {
        let session = LanguageModelSession()
        let targetWordCount = Int(Double(parameters.duration) * 2.5)
        var composedPrompt = "Tell a story for children about \(parameters.topic). Use simple words, a friendly and positive tone, and a clear, fun plot. Avoid anything scary or negative."
        if let name = parameters.characterName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            composedPrompt += " The main character is named \(name)."
        }
        if let kid = parameters.kidNames.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            composedPrompt += " Include a kid named \(kid) in the story."
        }
        if let kidAges = parameters.kidAges, !kidAges.isEmpty {
            let agesString = kidAges.map { String($0) }.joined(separator: ", ")
            composedPrompt += " The story should be age-appropriate for kids aged \(agesString)."
        }
        composedPrompt += " The story should take about \(parameters.duration) seconds to read aloud (about \(targetWordCount) words)."

        // Generate story outline
        let outline = try await session.respond(
            to: "Create an outline for a children's story: \(composedPrompt)",
            generating: StoryOutline.self
        )
        let title = outline.content.title

        // Get kid-appropriate section titles
        let sectionsResponse = try await session.respond(
            to: "Based on the outline for the children's story '\(title)',  fun,kid-appropriate. Only return the array, nothing else."
        )
        let sectionTitles: [String]
        if let data = sectionsResponse.content.data(using: .utf8), let parsed = try? JSONDecoder().decode([String].self, from: data) {
            sectionTitles = parsed
        } else {
            sectionTitles = sectionsResponse.content
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        var partialStory = "\n🏷️ Title: \(title)\n"
        onUpdate(partialStory, false)

        for (idx, section) in sectionTitles.enumerated() {
            let storySection = try await session.respond(
                to: "Write Section \(idx + 1): '\(section)' for the children's story '\(title)'. Use 1-2 short, simple paragraphs. Be concrete, friendly, and advance the plot, focusing on clear actions."
            )
//            partialStory += "\n\nSection \(idx + 1): \(section)\n" + storySection.content
            partialStory += storySection.content
            
            let isFinished = idx == sectionTitles.count - 1
            onUpdate(partialStory, isFinished)
        }

        let highLevelDescription: String = {
            let protagonist = outline.content.protagonist
            let conflict = outline.content.conflict
            let setting = outline.content.setting
            let genre = String(describing: outline.content.genre)
            let themes = outline.content.themes.joined(separator: ", ")
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

// Note for developers:
// Please check for duplicate definitions of StoryHistoryView and StorySettingsView in the project.
// Remove any extra or conflicting copies to avoid build issues.

