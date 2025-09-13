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
        TopicOption(title: "Farmyard Fables", image: "tractor"),
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
        var id: String {
            switch self {
            case .play(let s): return "play_" + s.id
            case .illustrate(let s): return "illustrate_" + s.id
            }
        }
        static func == (lhs: Route, rhs: Route) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }
    @State private var route: Route? = nil
    @State private var pendingStory: SavedStory? = nil
    @State private var showActionSheet: Bool = false
    
    @State private var showModelUnavailableAlert = false
    
    @State private var showConfetti = false
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private func speakGreeting(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.25
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }
    
    init() {
        let loadedSettings = UserDefaults.standard.loadStorySettings()
        _settings = State(initialValue: loadedSettings)
        _charactersText = State(initialValue: loadedSettings.defaultKidName)
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
            TextField("Main Characters (comma-separated, optional)", text: $charactersText)
        }
    }
    
    private var generateButtonSection: some View {
        Section {
            Button("Generate Story") {
                HapticEngine.play(.play)
                Task {
                    await generateStory()
                }
            }
            .disabled(isGenerating || topicIsEmpty)
        }
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
                    ScrollView {
                        Text(storyContent)
                            .font(.body)
                            .padding(.vertical)
                    }
                    .frame(minHeight: 100)
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
    }
    
    private var topicIsEmpty: Bool {
        if topicOptions[selectedTopicIndex].title == "Custom..." {
            return customTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }
    
    
    // Removed DuoLingo-related animation functions
    
    func generateStory() async {
       
        
        isGenerating = true
        storyContent = ""
        let resolvedTopic = topicOptions[selectedTopicIndex].title == "Custom..." ? customTopic : topicOptions[selectedTopicIndex].title
        let namesArray: [String]
        let trimmedCharacters = charactersText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCharacters.isEmpty {
            namesArray = []
        } else {
            namesArray = trimmedCharacters.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        let kidAgesDict = UserDefaults.standard.dictionary(forKey: "storySettingsKey") as? [String: Int] ?? [:]
        let kidAges = namesArray.map { kidAgesDict[$0] ?? 0 }
        
        let parameters = StoryGenerationParameters(
            topic: resolvedTopic,
            duration: Int(duration),
            characterName: nil,
            kidNames: namesArray,
            kidAges: kidAges,
            kidPictures: []
        )
        do {
            _ = try await StoryGenerator.shared.generateKidFriendlyStory(with: parameters) { partialStory, isFinished in
                storyContent = partialStory
                if isFinished {
                    isGenerating = false
                    showConfetti = true
                }
            }
        } catch {
            isGenerating = false
            storyContent = "Sorry, there was an error generating your story. Please try again."
            HapticEngine.play(.error)
        }
    }
}

#Preview {
    StoryGeneratorView()
}
