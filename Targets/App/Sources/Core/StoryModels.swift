// StoryModels.swift
// Contains model structs for Story Buddy

import Foundation

struct SavedStory: Codable, Identifiable, Equatable {
    let id: String // UUID string
    let title: String
    let description: String
    let content: String
    let date: Date
    let duration: Int // seconds
    let type: String // preset topic or custom
    let kidNames: [String]
}

struct StoryGenerationParameters {
    let topic: String
    let duration: Int // seconds
    let characterName: String?
    let kidNames: [String]
    let kidAges: [Int]? // Optional ages for each kid, by index
    let kidPictures: [Data?] // Optional images for each kid, by index
}
