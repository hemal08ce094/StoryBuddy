//
//  StoryGamePlayView.swift
//  AIStoryBuddy
//
//  Interactive game view with multiple game mechanics
//

import SwiftUI

struct StoryGamePlayView: View {
    let game: StoryGame
    let playerName: String
    
    @State private var currentChallengeIndex = 0
    @State private var score = 0
    @State private var completedChallenges = 0
    @State private var selectedAnswer: String? = nil
    @State private var isAnswerCorrect: Bool? = nil
    @State private var showingResult = false
    @State private var gameCompleted = false
    @State private var startTime = Date()
    @State private var showCelebration = false
    @Environment(\.dismiss) var dismiss
    
    private var currentChallenge: GameChallenge? {
        guard game.challenges.indices.contains(currentChallengeIndex) else { return nil }
        return game.challenges[currentChallengeIndex]
    }
    
    private var progress: Double {
        Double(currentChallengeIndex) / Double(max(1, game.challenges.count))
    }
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if gameCompleted {
                gameCompletedView
            } else if let challenge = currentChallenge {
                VStack(spacing: 0) {
                    // Header with progress
                    gameHeader
                    
                    // Challenge content
                    ScrollView {
                        VStack(spacing: 24) {
                            challengeCard(challenge)
                            answerButtons(challenge)
                        }
                        .padding()
                    }
                }
            }
            
            // Celebration overlay
            if showCelebration {
                ConfettiEffect()
                    .allowsHitTesting(false)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(gameCompleted)
    }
    
    // MARK: - Game Header
    
    private var gameHeader: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 20)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 20)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 20)
            .padding(.horizontal)
            
            // Stats row
            HStack(spacing: 20) {
                statBadge(icon: "star.fill", value: "\(score)", color: .yellow)
                Spacer()
                statBadge(icon: "checkmark.circle.fill", value: "\(currentChallengeIndex + 1)/\(game.challenges.count)", color: .green)
                Spacer()
                statBadge(icon: "flame.fill", value: "\(completedChallenges)", color: .orange)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(.ultraThinMaterial)
    }
    
    private func statBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - Challenge Card
    
    private func challengeCard(_ challenge: GameChallenge) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Challenge type badge
            HStack {
                Image(systemName: gameTypeIcon(challenge.type))
                    .font(.title3)
                Text(challenge.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(gameTypeColor(challenge.type))
            .clipShape(Capsule())
            
            // Challenge title
            Text(challenge.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            // Description
            Text(challenge.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Story context
            VStack(alignment: .leading, spacing: 8) {
                Text("From the story:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(challenge.storyContext)
                    .font(.callout)
                    .italic()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Difficulty stars
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Image(systemName: index < challenge.difficulty ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                Text("Difficulty")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Answer Buttons
    
    private func answerButtons(_ challenge: GameChallenge) -> some View {
        let allAnswers = ([challenge.correctAnswer] + challenge.wrongAnswers).shuffled()
        
        return VStack(spacing: 16) {
            ForEach(allAnswers, id: \.self) { answer in
                answerButton(answer: answer, challenge: challenge)
            }
        }
    }
    
    private func answerButton(answer: String, challenge: GameChallenge) -> some View {
        Button {
            selectAnswer(answer, challenge: challenge)
        } label: {
            HStack {
                Text(answer)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                Spacer()
                if selectedAnswer == answer {
                    Image(systemName: isAnswerCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(isAnswerCorrect == true ? .green : .red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(buttonColor(for: answer))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(borderColor(for: answer), lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedAnswer != nil)
        .scaleEffect(selectedAnswer == answer ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: selectedAnswer)
    }
    
    private func buttonColor(for answer: String) -> Color {
        guard let selected = selectedAnswer else {
            return Color.white.opacity(0.9)
        }
        
        if answer == selected {
            return isAnswerCorrect == true ? Color.green.opacity(0.2) : Color.red.opacity(0.2)
        }
        return Color.white.opacity(0.5)
    }
    
    private func borderColor(for answer: String) -> Color {
        guard let selected = selectedAnswer, answer == selected else {
            return Color.clear
        }
        return isAnswerCorrect == true ? .green : .red
    }
    
    // MARK: - Game Logic
    
    private func selectAnswer(_ answer: String, challenge: GameChallenge) {
        HapticEngine.play(.selection)
        selectedAnswer = answer
        isAnswerCorrect = (answer == challenge.correctAnswer)
        
        if isAnswerCorrect == true {
            score += challenge.points
            completedChallenges += 1
            HapticEngine.play(.success)
            showCelebration = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCelebration = false
            }
        } else {
            HapticEngine.play(.error)
        }
        
        // Move to next challenge after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if currentChallengeIndex < game.challenges.count - 1 {
                currentChallengeIndex += 1
                selectedAnswer = nil
                isAnswerCorrect = nil
            } else {
                completeGame()
            }
        }
    }
    
    private func completeGame() {
        let timeSpent = Date().timeIntervalSince(startTime)
        let session = GameSession(
            id: UUID().uuidString,
            gameID: game.id,
            playerName: playerName,
            score: score,
            totalPossible: game.totalPoints,
            completedChallenges: completedChallenges,
            totalChallenges: game.challenges.count,
            playedDate: Date(),
            timeSpent: timeSpent
        )
        
        StoryGameGenerator.shared.saveGameSession(session)
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            gameCompleted = true
        }
        
        HapticEngine.play(.success)
        showCelebration = true
    }
    
    // MARK: - Game Completed View
    
    private var gameCompletedView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Medal
            Text(GameSession.Medal(rawValue: "🥇")?.rawValue ?? "⭐")
                .font(.system(size: 100))
                .scaleEffect(showCelebration ? 1.2 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: showCelebration)
            
            // Score
            VStack(spacing: 8) {
                Text("Amazing!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                
                Text("\(score) Points")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("\(completedChallenges) out of \(game.challenges.count) challenges completed")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Percentage
                let percentage = Int((Double(score) / Double(max(1, game.totalPoints))) * 100)
                Text("\(percentage)% Score")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                Button {
                    // Reset and play again
                    currentChallengeIndex = 0
                    score = 0
                    completedChallenges = 0
                    selectedAnswer = nil
                    isAnswerCorrect = nil
                    gameCompleted = false
                    startTime = Date()
                    showCelebration = false
                    HapticEngine.play(.play)
                } label: {
                    Label("Play Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func gameTypeIcon(_ type: GameType) -> String {
        switch type {
        case .tapSequence: return "hand.tap.fill"
        case .choiceAdventure: return "arrow.triangle.branch"
        case .memoryMatch: return "brain.head.profile"
        case .dragAndDrop: return "arrow.up.and.down.and.arrow.left.and.right"
        case .rhythmTap: return "waveform"
        }
    }
    
    private func gameTypeColor(_ type: GameType) -> Color {
        switch type {
        case .tapSequence: return .blue
        case .choiceAdventure: return .purple
        case .memoryMatch: return .orange
        case .dragAndDrop: return .green
        case .rhythmTap: return .pink
        }
    }
}

#Preview {
    NavigationStack {
        StoryGamePlayView(
            game: StoryGame(
                storyID: "test",
                storyTitle: "Space Adventure",
                challenges: [
                    GameChallenge(
                        type: .choiceAdventure,
                        title: "Where did Alex go?",
                        description: "Choose the correct location from the story",
                        storyContext: "Alex zoomed through the stars to find a new planet.",
                        correctAnswer: "A new planet",
                        wrongAnswers: ["The moon", "Mars", "Earth"],
                        difficulty: 1,
                        points: 20
                    )
                ]
            ),
            playerName: "Player 1"
        )
    }
}
