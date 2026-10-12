//
//  GameHistoryView.swift
//  AIStoryBuddy
//
//  Game results, leaderboards, and achievements system
//

import SwiftUI

struct GameHistoryView: View {
    @State private var gameSessions: [GameSession] = []
    @State private var selectedFilter: FilterOption = .all
    
    enum FilterOption: String, CaseIterable {
        case all = "All Games"
        case today = "Today"
        case thisWeek = "This Week"
        case highScores = "High Scores"
    }
    
    var filteredSessions: [GameSession] {
        let sessions = gameSessions
        
        switch selectedFilter {
        case .all:
            return sessions.sorted { $0.playedDate > $1.playedDate }
        case .today:
            return sessions.filter { Calendar.current.isDateInToday($0.playedDate) }
                .sorted { $0.playedDate > $1.playedDate }
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return sessions.filter { $0.playedDate > weekAgo }
                .sorted { $0.playedDate > $1.playedDate }
        case .highScores:
            return sessions.sorted { $0.score > $1.score }
        }
    }
    
    // Achievement stats
    private var totalGamesPlayed: Int {
        gameSessions.count
    }
    
    private var totalScore: Int {
        gameSessions.reduce(0) { $0 + $1.score }
    }
    
    private var averageScore: Int {
        guard !gameSessions.isEmpty else { return 0 }
        return totalScore / gameSessions.count
    }
    
    private var goldMedals: Int {
        gameSessions.filter { $0.medal == .gold }.count
    }
    
    private var silverMedals: Int {
        gameSessions.filter { $0.medal == .silver }.count
    }
    
    private var bronzeMedals: Int {
        gameSessions.filter { $0.medal == .bronze }.count
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Achievement stats
                    achievementStatsSection
                    
                    // Medal showcase
                    medalShowcaseSection
                    
                    // Filter picker
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(FilterOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Game sessions list
                    if filteredSessions.isEmpty {
                        emptyStateView
                    } else {
                        gameSessionsList
                    }
                }
                .padding(.vertical)
            }
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Game History")
            .onAppear {
                loadGameSessions()
            }
        }
    }
    
    // MARK: - Achievement Stats Section
    
    private var achievementStatsSection: some View {
        VStack(spacing: 16) {
            Text("Your Gaming Stats")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statCard(title: "Games", value: "\(totalGamesPlayed)", icon: "gamecontroller.fill", color: .blue)
                statCard(title: "Total Score", value: "\(totalScore)", icon: "star.fill", color: .yellow)
                statCard(title: "Avg Score", value: "\(averageScore)", icon: "chart.line.uptrend.xyaxis", color: .green)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Medal Showcase
    
    private var medalShowcaseSection: some View {
        VStack(spacing: 12) {
            Text("Medal Collection")
                .font(.headline)
            
            HStack(spacing: 32) {
                medalBadge(emoji: "🥇", count: goldMedals, title: "Gold")
                medalBadge(emoji: "🥈", count: silverMedals, title: "Silver")
                medalBadge(emoji: "🥉", count: bronzeMedals, title: "Bronze")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
    
    private func medalBadge(emoji: String, count: Int, title: String) -> some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 48))
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Game Sessions List
    
    private var gameSessionsList: some View {
        VStack(spacing: 12) {
            ForEach(filteredSessions) { session in
                GameSessionCard(session: session)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Games Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Play a story game to see your results here!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
    
    // MARK: - Helper
    
    private func loadGameSessions() {
        gameSessions = StoryGameGenerator.shared.loadGameSessions()
    }
}

// MARK: - Game Session Card

struct GameSessionCard: View {
    let session: GameSession
    
    var body: some View {
        HStack(spacing: 16) {
            // Medal
            Text(session.medal.rawValue)
                .font(.system(size: 40))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.playerName)
                    .font(.headline)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Label("\(session.score)", systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(session.percentage)%")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(session.completedChallenges)/\(session.totalChallenges)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(session.playedDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Score percentage circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: Double(session.percentage) / 100.0)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Text("\(session.percentage)%")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    GameHistoryView()
}
