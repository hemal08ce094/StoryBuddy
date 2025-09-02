import SwiftUI

struct SavedStoryListView: View {
    @State private var savedStories: [SavedStory]

    // Routing
    private enum Route: Identifiable, Hashable {
        case play(SavedStory)
        case illustrate(SavedStory)

        var id: String {
            switch self {
            case .play(let s): return "play_" + s.id
            case .illustrate(let s): return "illustrate_" + s.id
            }
        }

        static func == (lhs: Route, rhs: Route) -> Bool {
            return lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    @State private var route: Route? = nil

    // Filters
    @State private var showFilterSheet: Bool = false
    @State private var selectedType: String? = nil
    @State private var selectedKid: String? = nil
    @State private var selectedDuration: Int? = nil

    init(savedStories: [SavedStory]) {
        _savedStories = State(initialValue: savedStories)
    }

    private var allTypes: [String] {
        let types = savedStories.map { $0.type.isEmpty ? "Unknown" : $0.type }
        return Array(Set(types)).sorted()
    }

    private var allKids: [String] {
        let kids = savedStories.flatMap { $0.kidNames }
        return Array(Set(kids)).sorted()
    }

    // Duration groups: nil, <30, 30–60, >60 seconds
    // Represent groups as Int? with meanings:
    // nil = All, 0 = <30, 1 = 30–60, 2 = >60
    private let durationGroups: [(label: String, value: Int?)] = [
        ("< 30s", 0),
        ("30s - 60s", 1),
        ("> 60s", 2)
    ]

    private var filteredStories: [SavedStory] {
        savedStories.filter { story in
            let typeMatches = selectedType == nil || (selectedType == "Unknown" ? story.type.isEmpty : story.type == selectedType)
            let kidMatches = selectedKid == nil || story.kidNames.contains(where: { $0 == selectedKid })
            let durationMatches: Bool
            if let selDur = selectedDuration {
                switch selDur {
                case 0: durationMatches = story.duration < 30
                case 1: durationMatches = story.duration >= 30 && story.duration <= 60
                case 2: durationMatches = story.duration > 60
                default: durationMatches = true
                }
            } else {
                durationMatches = true
            }
            return typeMatches && kidMatches && durationMatches
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredStories) { story in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { SavedStoryRow(story: story); Spacer() }
                        .padding(.vertical, 6)

                    HStack(spacing: 12) {
                        Button("Play Story") {
                            // Optional: keep your haptics if available
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            route = .play(story)
                        }
                        .buttonStyle(.glassProminent)

                        Button("Story illustrations") {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            #endif
                            route = .illustrate(story)
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Saved Stories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .onAppear {
                savedStories = StoryGenerator.shared.savedStories()
            }
            // Navigation destinations
            .navigationDestination(item: $route) { dest in
                switch dest {
                case .play(let story):
                    StoryPlayerView(story: story, duration: story.duration)
                case .illustrate(let visualStory):
                    let pipeline = IllustrationPipeline() // same extractor / prompt composer
                    IllustrationSceneListView(story: visualStory, pipeline: pipeline)
                }
            }
            // Filters remain a sheet
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    allTypes: allTypes,
                    allKids: allKids,
                    durationGroups: durationGroups,
                    selectedType: $selectedType,
                    selectedKid: $selectedKid,
                    selectedDuration: $selectedDuration,
                    isPresented: $showFilterSheet
                )
            }
        }
    }
}

private struct SavedStoryRow: View {
    let story: SavedStory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            iconView
                .frame(width: 40, height: 40)
                .background(iconBackgroundColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(story.title)
                    .font(.headline)
                    .bold()

                HStack(spacing: 8) {
                    // Duration badge
                    Label("\(story.duration)s", systemImage: "clock")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())

                    // Type badge (Custom or topic)
                    Text(typeText)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())

                    // Kid names as capsule badges
                    ForEach(story.kidNames, id: \.self) { kidName in
                        Text(kidName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                Text(story.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(story.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private var iconName: String {
        if story.type.lowercased() != "custom" {
            return "sparkles"
        } else if story.type.lowercased() == "custom" {
            return "pencil"
        } else {
            return "book"
        }
    }

    private var iconView: some View {
        Image(systemName: iconName)
            .font(.title2)
            .foregroundColor(.white)
    }

    private var iconBackgroundColor: Color {
        if story.type.lowercased() != "custom" {
            return Color.purple
        } else if story.type.lowercased() == "custom" {
            return Color.orange
        } else {
            return Color.green
        }
    }

    private var typeText: String {
        if story.type.lowercased() == "custom" {
            return "Custom"
        }
        return story.type.isEmpty ? "Unknown" : story.type
    }
}

private struct FilterSheet: View {
    let allTypes: [String]
    let allKids: [String]
    let durationGroups: [(label: String, value: Int?)]

    @Binding var selectedType: String?
    @Binding var selectedKid: String?
    @Binding var selectedDuration: Int?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Type")) {
                    Picker("Type", selection: Binding<String?>(
                        get: { selectedType },
                        set: { newValue in selectedType = newValue }
                    )) {
                        Text("All").tag(String?.none)
                        ForEach(allTypes, id: \.self) { type in
                            Text(type).tag(Optional(type))
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .labelsHidden()
                }

                Section(header: Text("Kid")) {
                    Picker("Kid", selection: Binding<String?>(
                        get: { selectedKid },
                        set: { newValue in selectedKid = newValue }
                    )) {
                        Text("All").tag(String?.none)
                        ForEach(allKids, id: \.self) { kid in
                            Text(kid).tag(Optional(kid))
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .labelsHidden()
                }

                Section(header: Text("Duration")) {
                    Picker("Duration", selection: Binding<Int?>(
                        get: { selectedDuration },
                        set: { newValue in selectedDuration = newValue }
                    )) {
                        Text("All").tag(Int?.none)
                        ForEach(durationGroups, id: \.value) { group in
                            Text(group.label).tag(group.value)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .labelsHidden()
                }

                Section {
                    Button("Reset Filters") {
                        selectedType = nil
                        selectedKid = nil
                        selectedDuration = nil
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}
