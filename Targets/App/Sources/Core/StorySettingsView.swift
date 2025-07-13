import SwiftUI

struct StorySettings: Codable, Equatable {
    var defaultAge: Int = 8
    var defaultKidName: String = "Alex"
    var gender: Bool = true
    // Add more settings as needed
}

struct StorySettingsView: View {
    @State private var settings: StorySettings = UserDefaults.standard.loadStorySettings()

    var body: some View {
        Form {
            Section(header: Text("General Preferences")
                .onTapGesture {
                    HapticEngine.play(.tap)
                }
            ) {
                TextField("Kid's Name", text: $settings.defaultKidName)
                    .onTapGesture {
                        HapticEngine.play(.selection)
                    }
                Stepper(value: $settings.defaultAge, in: 3...15) {
                    HStack {
                        Text("Preferred Age: ")
                        Spacer()
                        Text("\(settings.defaultAge)")
                    }
                }
                .onChange(of: settings.defaultAge) { _ in
                    HapticEngine.play(.scrub)
                }
            }
        }
        .navigationTitle("Settings")
        .onDisappear {
            UserDefaults.standard.saveStorySettings(settings)
            HapticEngine.play(.success)
        }
    }
}

#Preview {
    StorySettingsView()
}
