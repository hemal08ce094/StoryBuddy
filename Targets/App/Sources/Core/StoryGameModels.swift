//
//  StoryGameModels.swift
//  AIStoryBuddy
//
//  Created by Claude Code
//  Story-to-Game Feature: Transform stories into interactive mini-games
//

import Foundation
import SwiftUI

// MARK: - Game Models

/// Represents different types of mini-games that can be generated from a story
enum GameType: String, Codable {
    case tapSequence = "Tap Sequence"
    case choiceAdventure = "Choice Adventure"
    case memoryMatch = "Memory Match"
    case dragAndDrop = "Drag & Drop"
    case rhythmTap = "Rhythm Tap"
}

/// A single game challenge extracted from the story
struct GameChallenge: Identifiable, Codable, Hashable {
    let id: UUID
    let type: GameType
    let title: String
    let description: String
    let storyContext: String // The part of the story this relates to
    let correctAnswer: String
    let wrongAnswers: [String]
    let difficulty: Int // 1-3
    let points: Int
    
    init(id: UUID = UUID(), type: GameType, title: String, description: String, storyContext: String, correctAnswer: String, wrongAnswers: [String], difficulty: Int = 1, points: Int = 10) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.storyContext = storyContext
        self.correctAnswer = correctAnswer
        self.wrongAnswers = wrongAnswers
        self.difficulty = difficulty
        self.points = points
    }
}

/// Complete game session for a story
struct StoryGame: Identifiable, Codable {
    let id: String
    let storyID: String
    let storyTitle: String
    let challenges: [GameChallenge]
    let totalPoints: Int
    let createdDate: Date
    
    init(id: String = UUID().uuidString, storyID: String, storyTitle: String, challenges: [GameChallenge], createdDate: Date = Date()) {
        self.id = id
        self.storyID = storyID
        self.storyTitle = storyTitle
        self.challenges = challenges
        self.totalPoints = challenges.reduce(0) { $0 + $1.points }
        self.createdDate = createdDate
    }
}

/// Player's game session results
struct GameSession: Identifiable, Codable {
    let id: String
    let gameID: String
    let playerName: String
    let score: Int
    let totalPossible: Int
    let completedChallenges: Int
    let totalChallenges: Int
    let playedDate: Date
    let timeSpent: TimeInterval
    
    var percentage: Int {
        guard totalPossible > 0 else { return 0 }
        return Int((Double(score) / Double(totalPossible)) * 100)
    }
    
    var medal: Medal {
        if percentage >= 90 { return .gold }
        if percentage >= 75 { return .silver }
        if percentage >= 60 { return .bronze }
        return .none
    }
    
    enum Medal: String {
        case gold = "🥇"
        case silver = "🥈"
        case bronze = "🥉"
        case none = "⭐"
    }
}

// MARK: - AI Response Model for Game Generation

struct GameGenerationOutline: Codable {
    let challenges: [ChallengeOutline]
    let recommendedGameType: String
    let difficultyLevel: Int
}

struct ChallengeOutline: Codable {
    let title: String
    let description: String
    let storyContext: String
    let correctAnswer: String
    let wrongAnswers: [String]
    let gameType: String
    let difficulty: Int
}
