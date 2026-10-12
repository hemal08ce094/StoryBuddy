//
//  StoryGameGenerator.swift
//  AIStoryBuddy
//
//  AI-powered system that converts stories into interactive games
//

import Foundation
import FoundationModels

@MainActor
class StoryGameGenerator {
    static let shared = StoryGameGenerator()
    
    private init() {}
    
    /// Generates an interactive game from a saved story using AI
    func generateGame(from story: SavedStory, numberOfChallenges: Int = 5) async throws -> StoryGame {
        let session = LanguageModelSession()
        
        // Create a prompt that asks AI to generate game challenges
        let gamePrompt = """
        You are a creative game designer for children. Given this story, create \(numberOfChallenges) fun, interactive game challenges that test comprehension and engagement.
        
        Story Title: \(story.title)
        Story Content: \(story.content)
        
        For each challenge, create:
        1. A clear title (5-10 words)
        2. A simple description of what to do
        3. The exact part of the story it relates to (quote 1-2 sentences)
        4. One correct answer
        5. Three plausible but incorrect answers
        6. A game type (choose from: "Tap Sequence", "Choice Adventure", "Memory Match", "Drag & Drop", "Rhythm Tap")
        7. Difficulty (1=easy, 2=medium, 3=hard)
        
        Make the challenges kid-friendly, engaging, and directly tied to story events. Mix different challenge types for variety.
        
        Return ONLY valid JSON in this exact format with no additional text:
        {
          "challenges": [
            {
              "title": "string",
              "description": "string",
              "storyContext": "string",
              "correctAnswer": "string",
              "wrongAnswers": ["string", "string", "string"],
              "gameType": "string",
              "difficulty": 1
            }
          ],
          "recommendedGameType": "Choice Adventure",
          "difficultyLevel": 2
        }
        """
        
        // Get AI response
        let response = try await session.respond(to: gamePrompt)
        let jsonString = response.content
        
        // Parse the JSON response
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GameGenerationError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let outline = try decoder.decode(GameGenerationOutline.self, from: jsonData)
        
        // Convert outline to game challenges
        let challenges = outline.challenges.prefix(numberOfChallenges).map { challengeOutline in
            let gameType = GameType(rawValue: challengeOutline.gameType) ?? .choiceAdventure
            let points = (challengeOutline.difficulty * 10) + 10 // Easy=20, Medium=30, Hard=40
            
            return GameChallenge(
                type: gameType,
                title: challengeOutline.title,
                description: challengeOutline.description,
                storyContext: challengeOutline.storyContext,
                correctAnswer: challengeOutline.correctAnswer,
                wrongAnswers: challengeOutline.wrongAnswers,
                difficulty: challengeOutline.difficulty,
                points: points
            )
        }
        
        let game = StoryGame(
            storyID: story.id,
            storyTitle: story.title,
            challenges: Array(challenges)
        )
        
        // Save the game
        saveGame(game)
        
        return game
    }
    
    // MARK: - Persistence
    
    private func saveGame(_ game: StoryGame) {
        var games = loadGames()
        games.removeAll(where: { $0.id == game.id })
        games.append(game)
        UserDefaults.standard.saveGames(games)
    }
    
    func loadGames() -> [StoryGame] {
        return UserDefaults.standard.loadGames()
    }
    
    func game(forStoryID storyID: String) -> StoryGame? {
        return loadGames().first { $0.storyID == storyID }
    }
    
    func saveGameSession(_ session: GameSession) {
        var sessions = loadGameSessions()
        sessions.append(session)
        UserDefaults.standard.saveGameSessions(sessions)
    }
    
    func loadGameSessions() -> [GameSession] {
        return UserDefaults.standard.loadGameSessions()
    }
    
    func sessions(forGameID gameID: String) -> [GameSession] {
        return loadGameSessions().filter { $0.gameID == gameID }.sorted { $0.score > $1.score }
    }
}

// MARK: - Errors

enum GameGenerationError: LocalizedError {
    case invalidResponse
    case parseError
    case insufficientStoryContent
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The AI couldn't generate a game. Please try again."
        case .parseError:
            return "Failed to process the game data."
        case .insufficientStoryContent:
            return "The story is too short to create a game. Try a longer story!"
        }
    }
}

// MARK: - UserDefaults Extensions

extension UserDefaults {
    private static let gamesKey = "savedStoryGames"
    private static let gameSessionsKey = "gameSessionHistory"
    
    func saveGames(_ games: [StoryGame]) {
        if let encoded = try? JSONEncoder().encode(games) {
            set(encoded, forKey: UserDefaults.gamesKey)
        }
    }
    
    func loadGames() -> [StoryGame] {
        guard let data = data(forKey: UserDefaults.gamesKey),
              let decoded = try? JSONDecoder().decode([StoryGame].self, from: data) else {
            return []
        }
        return decoded
    }
    
    func saveGameSessions(_ sessions: [GameSession]) {
        if let encoded = try? JSONEncoder().encode(sessions) {
            set(encoded, forKey: UserDefaults.gameSessionsKey)
        }
    }
    
    func loadGameSessions() -> [GameSession] {
        guard let data = data(forKey: UserDefaults.gameSessionsKey),
              let decoded = try? JSONDecoder().decode([GameSession].self, from: data) else {
            return []
        }
        return decoded
    }
}
