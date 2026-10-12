//
//  StoryUniquenessEngine.swift
//  AIStoryBuddy
//
//  AI-powered system to ensure story variety and prevent repetition
//

import Foundation
import FoundationModels

// MARK: - Story DNA Models

/// Represents the unique elements that make up a story's "DNA"
struct StoryDNA: Codable, Hashable {
    let plotTwist: String
    let setting: String
    let conflict: String
    let emotion: String
    let lesson: String
    let magicalElement: String?
    let uniqueCharacter: String?
    
    var fingerprint: String {
        "\(plotTwist)-\(setting)-\(conflict)-\(emotion)"
    }
}

/// Tracks story history to prevent repetition
struct StoryHistory: Codable {
    var generatedDNAs: [String] = [] // Fingerprints of generated stories
    var recentThemes: [String] = [] // Last 10 themes used
    var recentSettings: [String] = [] // Last 10 settings used
    var usageCount: [String: Int] = [:] // How many times each element was used
    var lastGenerationDate: Date = Date()
}

// MARK: - Story Uniqueness Engine

@MainActor
class StoryUniquenessEngine {
    static let shared = StoryUniquenessEngine()
    
    private init() {}
    
    /// Generate unique story DNA using AI
    func generateUniqueDNA(for topic: String, avoidSimilarTo previousStories: [SavedStory]) async throws -> StoryDNA {
        let session = LanguageModelSession()
        
        // Extract elements from previous stories to avoid
        let history = loadHistory()
        let recentElements = buildAvoidanceList(from: history)
        
        let prompt = """
        You are a creative story architect. Generate a UNIQUE and FRESH story concept for a children's story about "\(topic)".
        
        IMPORTANT: Make this story DIFFERENT from typical stories. Avoid these overused elements:
        \(recentElements)
        
        Generate a completely unique combination of these elements (return ONLY valid JSON):
        {
          "plotTwist": "An unexpected twist that makes the story memorable (be creative!)",
          "setting": "An unusual, specific location (not just 'forest' or 'space' - be detailed!)",
          "conflict": "The main challenge or problem (make it unique and age-appropriate)",
          "emotion": "Primary emotion the story explores (beyond just 'happy')",
          "lesson": "The valuable lesson learned (subtle, not preachy)",
          "magicalElement": "Optional magical or fantastical element to add wonder",
          "uniqueCharacter": "A unique supporting character (animal, object, or person with distinct personality)"
        }
        
        Be CREATIVE and SPECIFIC. Avoid clichés. Think of combinations that haven't been done before!
        Examples of good uniqueness:
        - Setting: "A library where books whisper their stories at midnight"
        - Plot twist: "The villain turns out to be lonely and just wanted friends"
        - Conflict: "Must teach a grumpy cloud how to smile again"
        
        Return ONLY the JSON, no other text.
        """
        
        let response: LanguageModelSession.Response<String>
        do {
            response = try await session.respond(to: prompt)
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error {
                let safetyPrefix = "Safety note: This is for young children. Avoid scary, violent, or unsafe themes. Keep everything gentle and age-appropriate."
                response = try await session.respond(to: safetyPrefix + "\n" + prompt)
            } else {
                throw error
            }
        }
        let rawContent = response.content
        let jsonContent = extractJSONObject(from: rawContent) ?? rawContent
        
        guard let jsonData = jsonContent.data(using: .utf8),
              let dna = try? JSONDecoder().decode(StoryDNA.self, from: jsonData) else {
            throw StoryUniquenessError.failedToGenerateDNA
        }
        
        // Save DNA fingerprint
        saveGeneratedDNA(dna)
        
        return dna
    }
    
    /// Build enhanced story prompt with uniqueness constraints
    func buildEnhancedPrompt(baseTopic: String, dna: StoryDNA, parameters: StoryGenerationParameters) -> String {
        var prompt = """
        Create a UNIQUE and ENGAGING children's story with these specific elements:
        
        TOPIC: \(baseTopic)
        
        STORY DNA (USE ALL OF THESE):
        - Plot Twist: \(dna.plotTwist)
        - Setting: \(dna.setting)
        - Main Conflict: \(dna.conflict)
        - Emotional Theme: \(dna.emotion)
        - Lesson: \(dna.lesson)
        """
        
        if let magical = dna.magicalElement {
            prompt += "\n- Magical Element: \(magical)"
        }
        
        if let character = dna.uniqueCharacter {
            prompt += "\n- Special Character: \(character)"
        }
        
        if !parameters.kidNames.isEmpty {
            prompt += "\n\nMAIN CHARACTERS: \(parameters.kidNames.joined(separator: ", "))"
            if let ages = parameters.kidAges, !ages.isEmpty {
                let agesStr = ages.map { String($0) }.joined(separator: ", ")
                prompt += " (ages: \(agesStr))"
            }
        }
        
        let targetAge = parameters.kidAges?.first ?? 8
        
        prompt += """
        
        
        REQUIREMENTS:
        - Target duration: \(parameters.duration) seconds (about \(Int(Double(parameters.duration) * 2.5)) words)
        - Age-appropriate for kids aged \(targetAge)
        - Use simple, clear language
        - Make it UNIQUE - this should feel fresh and different
        - Include sensory details (what they see, hear, feel)
        - Build tension naturally
        - Satisfying resolution with the lesson woven in
        
        Write an engaging, one-of-a-kind story that incorporates ALL the story DNA elements above!
        """
        
        return prompt
    }
    
    /// Check if a story is too similar to recent stories
    func isTooSimilar(to recentStories: [SavedStory], newStory: String) -> Bool {
        guard recentStories.count >= 3 else { return false }
        
        let recent = recentStories.prefix(5)
        let newWords = Set(newStory.lowercased().split(separator: " "))
        
        for story in recent {
            let existingWords = Set(story.content.lowercased().split(separator: " "))
            let intersection = newWords.intersection(existingWords)
            let similarity = Double(intersection.count) / Double(newWords.count)
            
            // If more than 40% of words overlap, it's too similar
            if similarity > 0.40 {
                return true
            }
        }
        
        return false
    }
    
    /// Get variety suggestions for user
    func getSuggestionForVariety(currentTopic: String) async throws -> String {
        let history = loadHistory()
        
        // Find what hasn't been used much
        let leastUsed = history.usageCount
            .sorted { $0.value < $1.value }
            .prefix(3)
            .map { $0.key }
        
        if leastUsed.isEmpty {
            return "Try exploring a new theme you haven't used before!"
        }
        
        return "For more variety, try: \(leastUsed.joined(separator: ", "))"
    }
    
    // MARK: - Private Helpers
    
    private func extractJSONObject(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}") else {
            return nil
        }
        guard startIndex < endIndex else {
            return nil
        }
        return String(text[startIndex...endIndex])
    }
    
    private func buildAvoidanceList(from history: StoryHistory) -> String {
        var avoid: [String] = []
        
        if !history.recentSettings.isEmpty {
            avoid.append("Settings recently used: \(history.recentSettings.prefix(5).joined(separator: ", "))")
        }
        
        if !history.recentThemes.isEmpty {
            avoid.append("Themes recently used: \(history.recentThemes.prefix(5).joined(separator: ", "))")
        }
        
        // Find overused elements
        let overused = history.usageCount
            .filter { $0.value >= 3 }
            .map { $0.key }
        
        if !overused.isEmpty {
            avoid.append("Overused elements to avoid: \(overused.joined(separator: ", "))")
        }
        
        return avoid.isEmpty ? "No restrictions - be creative!" : avoid.joined(separator: "\n")
    }
    
    private func saveGeneratedDNA(_ dna: StoryDNA) {
        var history = loadHistory()
        
        // Save fingerprint
        history.generatedDNAs.append(dna.fingerprint)
        if history.generatedDNAs.count > 50 {
            history.generatedDNAs.removeFirst(10) // Keep last 50
        }
        
        // Track elements
        history.recentSettings.append(dna.setting)
        if history.recentSettings.count > 10 {
            history.recentSettings.removeFirst()
        }
        
        history.recentThemes.append(dna.emotion)
        if history.recentThemes.count > 10 {
            history.recentThemes.removeFirst()
        }
        
        // Increment usage count
        history.usageCount[dna.setting, default: 0] += 1
        history.usageCount[dna.conflict, default: 0] += 1
        history.usageCount[dna.emotion, default: 0] += 1
        
        history.lastGenerationDate = Date()
        
        saveHistory(history)
    }
    
    // MARK: - Persistence
    
    private func loadHistory() -> StoryHistory {
        guard let data = UserDefaults.standard.data(forKey: "storyHistory"),
              let history = try? JSONDecoder().decode(StoryHistory.self, from: data) else {
            return StoryHistory()
        }
        return history
    }
    
    private func saveHistory(_ history: StoryHistory) {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "storyHistory")
        }
    }
    
    /// Reset history (for testing or user request)
    func resetHistory() {
        UserDefaults.standard.removeObject(forKey: "storyHistory")
    }
    
    /// Get statistics about story variety
    func getVarietyStats() -> (uniqueStories: Int, mostUsedElement: String?, varietyScore: Int) {
        let history = loadHistory()
        let uniqueCount = Set(history.generatedDNAs).count
        
        let mostUsed = history.usageCount.max(by: { $0.value < $1.value })
        
        // Variety score: 0-100 based on uniqueness
        let totalGenerated = history.generatedDNAs.count
        let varietyScore = totalGenerated > 0 ? Int((Double(uniqueCount) / Double(totalGenerated)) * 100) : 100
        
        return (uniqueCount, mostUsed?.key, varietyScore)
    }
}

// MARK: - Errors

enum StoryUniquenessError: LocalizedError {
    case failedToGenerateDNA
    case tooSimilarToRecent
    
    var errorDescription: String? {
        switch self {
        case .failedToGenerateDNA:
            return "Failed to generate unique story elements. Please try again."
        case .tooSimilarToRecent:
            return "This story is too similar to a recent one. Generating a fresh version..."
        }
    }
}
