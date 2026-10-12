import SwiftUI
import FoundationModels
import Foundation
import SwiftUI
import AVFoundation

struct TopicButtonView: View {
    let option: StoryGeneratorView.TopicOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack {
            Image(systemName: option.image)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundColor(isSelected ? .accentColor : .secondary)
            Text(option.title)
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticEngine.play(.selection)
            action()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct StoryGeneratorView: View {
    // Removed DuoLingo-related animation actions
    
    struct TopicOption: Identifiable {
        var id: String { title }
        let title: String
        let image: String
    }
    
    private let topicOptions = [
        TopicOption(title: "Space Adventure", image: "sparkles"),
        TopicOption(title: "Jungle Quest", image: "leaf"),
        TopicOption(title: "Pirate Voyage", image: "sailboat"),
        TopicOption(title: "Mystery Mansion", image: "house"),
        TopicOption(title: "Underwater World", image: "tortoise"),
        TopicOption(title: "Dinosaur Days", image: "hare"),
        TopicOption(title: "Superhero Mission", image: "bolt.fill"),
        TopicOption(title: "Magic School", image: "wand.and.stars"),
        TopicOption(title: "Animal Friends", image: "pawprint"),
        TopicOption(title: "Fairy Tale Forest", image: "tree"),
        TopicOption(title: "Time Travel", image: "clock.arrow.circlepath"),
        TopicOption(title: "Robot Rescue", image: "gearshape.2"),
        TopicOption(title: "Treasure Hunt", image: "map"),
        TopicOption(title: "Birthday Surprise", image: "gift"),
        TopicOption(title: "Circus Fun", image: "tent.2"),
        TopicOption(title: "Lost in the Snow", image: "snowflake"),
        TopicOption(title: "Camping Trip", image: "tent"),
        TopicOption(title: "Farmyard Fables", image: "leaf.circle"),
        TopicOption(title: "Monster Party (Friendly)", image: "face.smiling"),
        TopicOption(title: "Custom...", image: "pencil")
    ]
    
    private let topicGreetings: [String: String] = [
        "Space Adventure": "🚀 Ready for liftoff? Let's zoom through the stars!",
        "Jungle Quest": "🌴 Let's swing into a wild jungle adventure!",
        "Pirate Voyage": "🏴‍☠️ Ahoy! A pirate's life for you!",
        "Mystery Mansion": "🏠 Shhh... mysteries await inside the mansion!",
        "Underwater World": "🐢 Dive in! Wonders await beneath the waves!",
        "Dinosaur Days": "🦕 Stomp, stomp! Let's meet some mighty dinos!",
        "Superhero Mission": "⚡ Up, up, and away! Time to save the day!",
        "Magic School": "✨ Grab your wand! School is full of surprises!",
        "Animal Friends": "🐾 Get ready for furry and feathered friends!",
        "Fairy Tale Forest": "🌳 Once upon a time, magic hides in the forest!",
        "Time Travel": "⏰ Whoosh! Where in time shall we go?",
        "Robot Rescue": "🤖 Beep boop! Robots need your help!",
        "Treasure Hunt": "🗺️ X marks the spot for treasure!",
        "Birthday Surprise": "🎁 Shh... it's time for a big birthday surprise!",
        "Circus Fun": "🎪 Step right up! The circus is in town!",
        "Lost in the Snow": "❄️ Brrr! Bundle up for a snowy adventure!",
        "Camping Trip": "🏕️ Let's tell stories under the stars!",
        "Farmyard Fables": "🚜 Moo, oink, neigh! Farm friends await!",
        "Monster Party (Friendly)": "😊 Monsters just wanna have fun!"
    ]

    @State private var settings: StorySettings = UserDefaults.standard.loadStorySettings()
    @State private var selectedTopicIndex: Int = 0
    @State private var customTopic: String = ""
    @State private var charactersText: String
    @State private var selectedKids: Set<String> = [] // Selected kid IDs
    @State private var duration: Double = 30
    @State private var storyContent: String = ""
    @State private var isGenerating: Bool = false
    @State private var isAnimatingLotus: Bool = false
    
    // Removed DuoLingo-related animation state
    
    @State private var currentSavedStory: SavedStory? = nil
    
    // Navigation routing
    private enum Route: Identifiable, Hashable {
        case play(SavedStory)
        case illustrate(SavedStory)
        case game(SavedStory)
        var id: String {
            switch self {
            case .play(let s): return "play_" + s.id
            case .illustrate(let s): return "illustrate_" + s.id
            case .game(let s): return "game_" + s.id
            }
        }
        static func == (lhs: Route, rhs: Route) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }
    @State private var route: Route? = nil
    @State private var pendingStory: SavedStory? = nil
    @State private var showActionSheet: Bool = false
    @State private var isGeneratingGame = false
    @State private var generatedGame: StoryGame? = nil
    
    @State private var showModelUnavailableAlert = false
    
    @State private var showConfetti = false
    @State private var varietyScore: Int = 100
    @State private var showVarietyInfo = false
    @State private var currentStoryDNA: StoryDNA? = nil
    @State private var showDNASheet = false
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private func getNaturalVoice() -> AVSpeechSynthesisVoice? {
        // Use same natural voice selection as StoryPlayerView
        let preferredVoices = [
            "com.apple.voice.premium.en-US.Zoe",
            "com.apple.voice.premium.en-US.Reed",
            "com.apple.voice.enhanced.en-US.Samantha",
            "com.apple.ttsbundle.siri_female_en-US_compact"
        ]
        
        for voiceIdentifier in preferredVoices {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
                return voice
            }
        }
        
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
            .first
    }
    
    private func speakGreeting(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = getNaturalVoice()
        utterance.rate = 0.52  // Slightly faster for greetings
        utterance.pitchMultiplier = 1.05  // Very slight lift for enthusiasm
        utterance.volume = 1.0
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }
    
    init() {
        let loadedSettings = UserDefaults.standard.loadStorySettings()
        _settings = State(initialValue: loadedSettings)
        _charactersText = State(initialValue: loadedSettings.defaultKidName)
        
        // Auto-select all kids by default
        let allKidIds = Set(loadedSettings.kidProfiles.map { $0.id })
        _selectedKids = State(initialValue: allKidIds)
    }
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                generatorContent
                    .navigationDestination(item: $route) { dest in
                        switch dest {
                        case .play(let story):
                            StoryPlayerView(story: story, duration: Int(duration))
                        case .illustrate(let visualStory):
                            let pipeline = IllustrationPipeline()
                            IllustrationSceneListView(story: visualStory, pipeline: pipeline)
                        case .game(let story):
                            if let game = generatedGame {
                                StoryGamePlayView(game: game, playerName: story.kidNames.first ?? "Player")
                            } else {
                                Text("Loading game...")
                            }
                        }
                    }
                    .confirmationDialog("What would you like to do?", isPresented: $showActionSheet, presenting: pendingStory) { story in
                        Button("Play Story") {
                            HapticEngine.play(.play)
                            route = .play(story)
                        }
                        Button("View Story") {
                            HapticEngine.play(.scrub)
                            route = .illustrate(story)
                        }
                        Button("Play Game 🎮") {
                            HapticEngine.play(.play)
                            Task {
                                await generateAndPlayGame(for: story)
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                    .alert("On-device Model Not Available", isPresented: $showModelUnavailableAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("The on-device Foundation model is not available. Please check your device settings or try again later.")
                    }
            }
        }
    }
    
    private var generatorContent: some View {
        VStack(spacing: 0) {
            Form {
                topicSection
                inputsSection
                generateButtonSection
                outputSection
            }
            playButtonSection
        }
        .navigationTitle("Story Generator")
        .onAppear {
            refreshSettings()
        }
    }
    
    private var topicSection: some View {
        Section(header: Text("Story Topic")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<topicOptions.count, id: \.self) { idx in
                        TopicButtonView(option: topicOptions[idx], isSelected: selectedTopicIndex == idx) {
                            selectedTopicIndex = idx
                            let title = topicOptions[idx].title
                            if title != "Custom...", let greeting = topicGreetings[title] {
                                speakGreeting(greeting)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            if topicOptions[selectedTopicIndex].title == "Custom..." {
                TextField("Custom Topic", text: $customTopic)
                    .padding(.top, 8)
            }
        }
    }
    
    private var inputsSection: some View {
        Section(header: Text("Story Inputs")) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duration (sec)")
                HStack {
                    Slider(value: $duration, in: 10...180, step: 10)
                        .onChange(of: duration) { _ in
                            HapticEngine.play(.scrub)
                        }
                    Text("\(Int(duration))")
                        .frame(width: 40, alignment: .trailing)
                }
            }
            
            // Kid profiles selector
            if !settings.kidProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Include Kids in Story")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if selectedKids.count > 0 {
                            Text("\(selectedKids.count) selected")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    
                    ForEach(settings.kidProfiles) { kid in
                        Button {
                            HapticEngine.play(.selection)
                            if selectedKids.contains(kid.id) {
                                selectedKids.remove(kid.id)
                            } else {
                                selectedKids.insert(kid.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedKids.contains(kid.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedKids.contains(kid.id) ? .blue : .gray)
                                    .font(.title3)
                                
                                // Mini avatar
                                ZStack {
                                    Circle()
                                        .fill(selectedKids.contains(kid.id) ? 
                                              LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                              LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 32, height: 32)
                                    
                                    Text(kid.name.prefix(1).uppercased())
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kid.name)
                                        .foregroundColor(.primary)
                                        .fontWeight(.medium)
                                    
                                    Text("\(kid.age) years old" + (!kid.favoriteAnimal.isEmpty ? " • Loves \(kid.favoriteAnimal)" : ""))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    
                    if selectedKids.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("Select at least one kid to personalize the story")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                NavigationLink(destination: StorySettingsView()) {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "person.2.badge.gearshape")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("Add Kids to Personalize Stories")
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                                Text("Stories are better with names and ages!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Fallback for additional characters
            TextField("Additional Characters (optional)", text: $charactersText)
        }
    }
    
    private var generateButtonSection: some View {
        Section {
            VStack(spacing: 12) {
                Button {
                    HapticEngine.play(.play)
                    Task {
                        await generateStory()
                    }
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGenerating ? "Creating Unique Story..." : "Generate Story")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isGenerating || topicIsEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isGenerating || topicIsEmpty)
                
                // Variety indicator
                HStack {
                    Image(systemName: varietyScore >= 80 ? "star.fill" : varietyScore >= 50 ? "star.leadinghalf.filled" : "star")
                        .foregroundColor(varietyScore >= 80 ? .green : varietyScore >= 50 ? .orange : .red)
                    
                    Text("Story Variety: \(varietyScore)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        showVarietyInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            updateVarietyScore()
        }
        .alert("Story Variety", isPresented: $showVarietyInfo) {
            Button("OK", role: .cancel) { }
            Button("Reset Variety") {
                StoryUniquenessEngine.shared.resetHistory()
                updateVarietyScore()
            }
        } message: {
            Text(varietyMessage)
        }
    }
    
    private var varietyMessage: String {
        if varietyScore >= 80 {
            return "Excellent! Your stories are unique and diverse. Keep exploring different themes!"
        } else if varietyScore >= 50 {
            return "Good variety, but try exploring new themes and settings to make stories even more unique."
        } else {
            return "Stories are becoming repetitive. Try different topics or tap 'Reset Variety' to start fresh."
        }
    }
    
    private func updateVarietyScore() {
        let stats = StoryUniquenessEngine.shared.getVarietyStats()
        varietyScore = stats.varietyScore
    }
    
    private var playButtonSection: some View {
        HStack {
            Spacer()
            Button {
                HapticEngine.play(.play)
                // Find or create a SavedStory for playback
                if let matched = StoryGenerator.shared.savedStories().first(where: { $0.content == storyContent }) {
                    pendingStory = matched
                    showActionSheet = true
                } else {
                    // Use first line or fallback title
                    let title = storyContent.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Story"
                    let newStory = SavedStory(
                        id: UUID().uuidString,
                        title: title,
                        description: "Custom story",
                        content: storyContent,
                        date: Date(),
                        duration: Int(duration),
                        type: topicOptions[selectedTopicIndex].title,
                        kidNames: {
                            let trimmedCharacters = charactersText.trimmingCharacters(in: .whitespacesAndNewlines)
                            return trimmedCharacters.isEmpty ? [] : trimmedCharacters.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        }()
                    )
                    pendingStory = newStory
                    showActionSheet = true
                }
            } label: {
                Label("Play Story", systemImage: "play.circle.fill")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("PlayStoryButton")
            .padding(.vertical, 10)
            .disabled(storyContent.isEmpty || isGenerating)
            Spacer()
        }
    }
    
    private var outputSection: some View {
        Section(header: Text("Output")) {
            ZStack {
                if isGenerating {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Preparing your story...")
                            .foregroundColor(.secondary)
                    }
                } else if !storyContent.isEmpty {
                    VStack(spacing: 12) {
                        // Story DNA Badge (if available)
                        if let dna = currentStoryDNA {
                            Button {
                                showDNASheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                    Text("View Story DNA")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                        
                        ScrollView {
                            Text(storyContent)
                                .font(.body)
                                .padding(.vertical)
                        }
                        .frame(minHeight: 100)
                    }
                } else {
                    Text("No story generated yet.")
                        .foregroundColor(.secondary)
                }
                
                if showConfetti {
                    ConfettiEffect()
                        .transition(.opacity)
                        .zIndex(10)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation { showConfetti = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showDNASheet) {
            if let dna = currentStoryDNA {
                StoryDNAView(dna: dna)
            }
        }
    }
    
    private var topicIsEmpty: Bool {
        if topicOptions[selectedTopicIndex].title == "Custom..." {
            return customTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }
    
    
    // Removed DuoLingo-related animation functions
    
    private func refreshSettings() {
        let latestSettings = UserDefaults.standard.loadStorySettings()
        settings = latestSettings
        let allKidIds = Set(latestSettings.kidProfiles.map { $0.id })
        let existingSelection = selectedKids.intersection(allKidIds)
        selectedKids = existingSelection.isEmpty ? allKidIds : existingSelection
    }
    
    func generateStory() async {
        isGenerating = true
        storyContent = ""
        if !SystemLanguageModel.default.isAvailable {
            isGenerating = false
            showModelUnavailableAlert = true
            return
        }
        let resolvedTopic = topicOptions[selectedTopicIndex].title == "Custom..." ? customTopic : topicOptions[selectedTopicIndex].title
        
        // Build names array from selected kid profiles
        var namesArray: [String] = []
        var kidAges: [Int] = []
        
        // Add selected kids from profiles
        let selectedKidProfiles = settings.kidProfiles.filter { selectedKids.contains($0.id) }
        for kid in selectedKidProfiles {
            namesArray.append(kid.name)
            kidAges.append(kid.age)
        }
        
        // Add additional characters from text field
        let trimmedCharacters = charactersText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCharacters.isEmpty {
            let additionalChars = trimmedCharacters.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            namesArray.append(contentsOf: additionalChars)
            // Default age for additional characters
            kidAges.append(contentsOf: Array(repeating: 8, count: additionalChars.count))
        }
        
        let parameters = StoryGenerationParameters(
            topic: resolvedTopic,
            duration: Int(duration),
            characterName: nil,
            kidNames: namesArray,
            kidAges: kidAges,
            kidPictures: []
        )
        do {
            _ = try await StoryGenerator.shared.generateKidFriendlyStory(
                with: parameters,
                onUpdate: { partialStory, isFinished in
                    Task { @MainActor in
                        storyContent = partialStory
                        if isFinished {
                            isGenerating = false
                            showConfetti = true
                            updateVarietyScore()
                        }
                    }
                },
                onDNAGenerated: { dna in
                    Task { @MainActor in
                        currentStoryDNA = dna
                    }
                }
            )
        } catch let error as LanguageModelSession.GenerationError {
            isGenerating = false
            switch error {
            case .assetsUnavailable:
                showModelUnavailableAlert = true
            default:
                storyContent = "Sorry, there was an error generating your story. Please try again."
                HapticEngine.play(.error)
            }
        } catch let error as FoundationModelsError {
            isGenerating = false
            if case .modelUnavailable = error {
                showModelUnavailableAlert = true
            } else {
                storyContent = "Sorry, there was an error generating your story. Please try again."
                HapticEngine.play(.error)
            }
        } catch {
            isGenerating = false
            storyContent = "Sorry, there was an error generating your story. Please try again."
            HapticEngine.play(.error)
        }
    }
    
    // MARK: - Game Generation
    
    private func generateAndPlayGame(for story: SavedStory) async {
        isGeneratingGame = true
        
        do {
            // Check if game already exists
            if let existingGame = StoryGameGenerator.shared.game(forStoryID: story.id) {
                generatedGame = existingGame
                route = .game(story)
            } else {
                // Generate new game
                let game = try await StoryGameGenerator.shared.generateGame(from: story, numberOfChallenges: 5)
                generatedGame = game
                route = .game(story)
            }
        } catch {
            // Handle error
            print("Error generating game: \(error)")
        }
        
        isGeneratingGame = false
    }
}

// MARK: - Story DNA View

struct StoryDNAView: View {
    let dna: StoryDNA
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Story DNA")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("The unique elements that make this story special")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // DNA Elements
                    VStack(spacing: 16) {
                        DNAElement(
                            icon: "sparkles",
                            title: "Plot Twist",
                            description: dna.plotTwist,
                            color: .yellow
                        )
                        
                        DNAElement(
                            icon: "location.fill",
                            title: "Setting",
                            description: dna.setting,
                            color: .green
                        )
                        
                        DNAElement(
                            icon: "exclamationmark.triangle.fill",
                            title: "Conflict",
                            description: dna.conflict,
                            color: .orange
                        )
                        
                        DNAElement(
                            icon: "heart.fill",
                            title: "Emotion",
                            description: dna.emotion,
                            color: .red
                        )
                        
                        DNAElement(
                            icon: "lightbulb.fill",
                            title: "Lesson",
                            description: dna.lesson,
                            color: .blue
                        )
                        
                        if let magical = dna.magicalElement {
                            DNAElement(
                                icon: "wand.and.stars",
                                title: "Magical Element",
                                description: magical,
                                color: .purple
                            )
                        }
                        
                        if let character = dna.uniqueCharacter {
                            DNAElement(
                                icon: "person.fill",
                                title: "Special Character",
                                description: character,
                                color: .pink
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DNAElement: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    StoryGeneratorView()
}
