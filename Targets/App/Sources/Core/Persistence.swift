// Persistence.swift
// Contains UserDefaults extensions for Story Buddy

import Foundation

extension UserDefaults {
    var savedStoriesKey: String { "savedStories" }

    func loadStories() -> [SavedStory] {
        guard let data = data(forKey: savedStoriesKey),
              let stories = try? JSONDecoder().decode([SavedStory].self, from: data) else {
            return []
        }
        return stories
    }

    func saveStories(_ stories: [SavedStory]) {
        if let data = try? JSONEncoder().encode(stories) {
            set(data, forKey: savedStoriesKey)
        }
    }
}

extension UserDefaults {
    static let storySettingsKey = "storySettingsKey"
    func loadStorySettings() -> StorySettings {
        if let data = data(forKey: UserDefaults.storySettingsKey),
           let settings = try? JSONDecoder().decode(StorySettings.self, from: data) {
            return settings
        }
        return StorySettings()
    }

    func saveStorySettings(_ settings: StorySettings) {
        if let data = try? JSONEncoder().encode(settings) {
            set(data, forKey: UserDefaults.storySettingsKey)
        }
    }
}

// Note: The StorySettings struct must be available from any file that uses this extension.
