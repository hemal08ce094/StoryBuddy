import SwiftUI
import AVFoundation

enum VoicePreference: String, Codable, CaseIterable {
    case female = "Female (Zoe)"
    case male = "Male (Reed)"
    case samantha = "Samantha (Classic)"
    case siri = "Siri Voice"
    case auto = "Auto (Best Available)"
    
    var voiceIdentifier: String? {
        switch self {
        case .female: return "com.apple.voice.premium.en-US.Zoe"
        case .male: return "com.apple.voice.premium.en-US.Reed"
        case .samantha: return "com.apple.voice.enhanced.en-US.Samantha"
        case .siri: return "com.apple.ttsbundle.siri_female_en-US_compact"
        case .auto: return nil
        }
    }
}

struct KidProfile: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var age: Int
    var favoriteColor: String = ""
    var favoriteAnimal: String = ""
    var interests: [String] = []
    
    init(id: String = UUID().uuidString, name: String, age: Int, favoriteColor: String = "", favoriteAnimal: String = "", interests: [String] = []) {
        self.id = id
        self.name = name
        self.age = age
        self.favoriteColor = favoriteColor
        self.favoriteAnimal = favoriteAnimal
        self.interests = interests
    }
}

struct StorySettings: Codable, Equatable {
    var defaultAge: Int = 8
    var defaultKidName: String = "Alex" // Kept for backward compatibility
    var gender: Bool = true
    var voicePreference: VoicePreference = .auto
    var speechRate: Double = 0.50
    var kidProfiles: [KidProfile] = [] // New: Multiple kid profiles
}

struct StorySettingsView: View {
    @State private var settings: StorySettings = UserDefaults.standard.loadStorySettings()
    @State private var showAddKidSheet = false
    @State private var editingKid: KidProfile?

    var body: some View {
        Form {
            Section(header: Text("Kid Profiles")) {
                if settings.kidProfiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No kids added yet")
                            .font(.headline)
                        Text("Add your kids to personalize stories!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(settings.kidProfiles) { kid in
                        KidProfileRow(kid: kid)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                HapticEngine.play(.selection)
                                editingKid = kid
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteKid(kid)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                
                Button {
                    HapticEngine.play(.play)
                    showAddKidSheet = true
                } label: {
                    Label("Add Kid", systemImage: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            Section(header: Text("Voice Settings")) {
                Picker("Narrator Voice", selection: $settings.voicePreference) {
                    ForEach(VoicePreference.allCases, id: \.self) { voice in
                        Text(voice.rawValue).tag(voice)
                    }
                }
                .onChange(of: settings.voicePreference) { _ in
                    HapticEngine.play(.selection)
                    testVoice()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Speech Speed")
                        Spacer()
                        Text(speedLabel)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.speechRate, in: 0.40...0.60, step: 0.02)
                        .onChange(of: settings.speechRate) { _ in
                            HapticEngine.play(.scrub)
                        }
                }
                
                Button("Test Voice") {
                    HapticEngine.play(.play)
                    testVoice()
                }
            }
            
            Section {
                Text("Choose a natural voice for story narration. Premium voices sound more human and expressive!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Story Settings")
        .sheet(isPresented: $showAddKidSheet) {
            AddKidView(settings: $settings)
        }
        .sheet(item: $editingKid) { kid in
            EditKidView(settings: $settings, kid: kid)
        }
        .onChange(of: settings) { newValue in
            UserDefaults.standard.saveStorySettings(newValue)
        }
        .onDisappear {
            UserDefaults.standard.saveStorySettings(settings)
            HapticEngine.play(.success)
        }
    }
    
    private func deleteKid(_ kid: KidProfile) {
        HapticEngine.play(.error)
        withAnimation {
            settings.kidProfiles.removeAll { $0.id == kid.id }
        }
        UserDefaults.standard.saveStorySettings(settings)
    }
    
    private var speedLabel: String {
        switch settings.speechRate {
        case 0.40..<0.47: return "Slower"
        case 0.47..<0.53: return "Normal"
        case 0.53...0.60: return "Faster"
        default: return "Normal"
        }
    }
    
    private func testVoice() {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "Hello! This is how I'll sound when telling your stories.")
        
        // Apply user settings
        if let voiceId = settings.voicePreference.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            // Use auto selection
            let preferredVoices = [
                "com.apple.voice.premium.en-US.Zoe",
                "com.apple.voice.premium.en-US.Reed",
                "com.apple.voice.enhanced.en-US.Samantha"
            ]
            
            for voiceIdentifier in preferredVoices {
                if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
                    utterance.voice = voice
                    break
                }
            }
        }
        
        utterance.rate = Float(settings.speechRate)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
}

// MARK: - Kid Profile Row

struct KidProfileRow: View {
    let kid: KidProfile
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                
                Text(kid.name.prefix(1).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(kid.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label("\(kid.age) years", systemImage: "birthday.cake")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !kid.favoriteAnimal.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(kid.favoriteAnimal)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !kid.interests.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(kid.interests.prefix(3), id: \.self) { interest in
                                Text(interest)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Kid View

struct AddKidView: View {
    @Binding var settings: StorySettings
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var age: Int = 8
    @State private var favoriteColor: String = ""
    @State private var favoriteAnimal: String = ""
    @State private var interestsText: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    
                    Stepper(value: $age, in: 2...15) {
                        HStack {
                            Text("Age")
                            Spacer()
                            Text("\(age) years")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Preferences (Optional)")) {
                    TextField("Favorite Color", text: $favoriteColor)
                        .textContentType(.none)
                    
                    TextField("Favorite Animal", text: $favoriteAnimal)
                        .textContentType(.none)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Interests (comma-separated)", text: $interestsText)
                            .textContentType(.none)
                        Text("E.g., dinosaurs, space, cooking")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("These details help create more personalized stories!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveKid()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveKid() {
        let interests = interestsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let newKid = KidProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            age: age,
            favoriteColor: favoriteColor.trimmingCharacters(in: .whitespaces),
            favoriteAnimal: favoriteAnimal.trimmingCharacters(in: .whitespaces),
            interests: interests
        )
        
        settings.kidProfiles.append(newKid)
        UserDefaults.standard.saveStorySettings(settings)
        HapticEngine.play(.success)
        dismiss()
    }
}

// MARK: - Edit Kid View

struct EditKidView: View {
    @Binding var settings: StorySettings
    let kid: KidProfile
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var age: Int = 8
    @State private var favoriteColor: String = ""
    @State private var favoriteAnimal: String = ""
    @State private var interestsText: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    
                    Stepper(value: $age, in: 2...15) {
                        HStack {
                            Text("Age")
                            Spacer()
                            Text("\(age) years")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Preferences (Optional)")) {
                    TextField("Favorite Color", text: $favoriteColor)
                        .textContentType(.none)
                    
                    TextField("Favorite Animal", text: $favoriteAnimal)
                        .textContentType(.none)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Interests (comma-separated)", text: $interestsText)
                            .textContentType(.none)
                        Text("E.g., dinosaurs, space, cooking")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("These details help create more personalized stories!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateKid()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadKidData()
            }
        }
    }
    
    private func loadKidData() {
        name = kid.name
        age = kid.age
        favoriteColor = kid.favoriteColor
        favoriteAnimal = kid.favoriteAnimal
        interestsText = kid.interests.joined(separator: ", ")
    }
    
    private func updateKid() {
        let interests = interestsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if let index = settings.kidProfiles.firstIndex(where: { $0.id == kid.id }) {
            settings.kidProfiles[index] = KidProfile(
                id: kid.id,
                name: name.trimmingCharacters(in: .whitespaces),
                age: age,
                favoriteColor: favoriteColor.trimmingCharacters(in: .whitespaces),
                favoriteAnimal: favoriteAnimal.trimmingCharacters(in: .whitespaces),
                interests: interests
            )
        }
        
        HapticEngine.play(.success)
        dismiss()
    }
}

#Preview {
    StorySettingsView()
}
