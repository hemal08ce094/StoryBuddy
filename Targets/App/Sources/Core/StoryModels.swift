// StoryModels.swift
// Contains model structs for Story Buddy

import Foundation

//struct SavedStory: Codable, Identifiable, Equatable {
//    let id: String // UUID string
//    let title: String // title of story
//    let description: String // descirption of story
//    let content: String // full content of story
//    let date: Date
//    let duration: Int // seconds
//    let type: String // preset topic or custom
//    let kidNames: [String] // kid name in story
//}

public struct SavedStory: Codable, Identifiable, Equatable {
    public let id: String // UUID string
    public let title: String // title of story
    public let description: String // description of story
    public let content: String // full content of story
    public let date: Date
    public let duration: Int // seconds
    public let type: String // preset topic or custom
    public let kidNames: [String] // kid name in story
}


struct StoryGenerationParameters {
    let topic: String
    let duration: Int // seconds
    let characterName: String?
    let kidNames: [String]
    let kidAges: [Int]? // Optional ages for each kid, by index
    let kidPictures: [Data?] // Optional images for each kid, by index
}
