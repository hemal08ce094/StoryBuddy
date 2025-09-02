//  IllustrationScenesKit.swift
//  AIStoryBuddy
//
//  COMPLETE, DROP-IN IMPLEMENTATION (Per‑scene generation only)
//  ------------------------------------------------------------
//  ✅ Uses your SavedStory model
//  ✅ Extracts kid-friendly scenes from content
//  ✅ Composes prompts using title + type + kidNames
//  ✅ Per‑scene "Generate" button that PRESENTS Image Playground
//  ✅ No batch generation (as requested)
//  ✅ Compiles on all SDKs; uses ImagePlaygroundConcept when available
//  ✅ Safe fallbacks (placeholder) if framework/device is unavailable
//
//  NOTE: We attempt to call the API you mentioned:
//    ImagePlaygroundConcept.extracted(from: conceptText, title: conceptTitle)
//  Then present the system UI and capture the selected image. If your SDK's
//  exact API names differ slightly, adjust inside `ImagePlaygroundBridge`.

import Foundation
import SwiftUI
import UIKit
#if canImport(ImagePlayground)
import ImagePlayground
#endif


// MARK: - Persisted illustration mapping (per story)
private struct SceneImage: Codable, Equatable {
    let index: Int             // Scene index (1-based)
    let imageURL: String       // File or remote URL string returned by Image Playground
}

private enum StoryIllustrationsStore {
    private static func key(for storyID: String) -> String { "story_\(storyID)_images" }

    static func load(for storyID: String) -> [SceneImage] {
        let k = key(for: storyID)
        guard let data = UserDefaults.standard.data(forKey: k) else { return [] }
        return (try? JSONDecoder().decode([SceneImage].self, from: data)) ?? []
    }

    static func save(_ items: [SceneImage], for storyID: String) {
        let k = key(for: storyID)
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: k)
        }
    }

    static func upsertImage(for storyID: String, index: Int, imageURL: URL) {
        var items = load(for: storyID)
        items.removeAll { $0.index == index }
        items.append(SceneImage(index: index, imageURL: imageURL.absoluteString))
        save(items, for: storyID)
    }
}

// MARK: - Scene model
public struct StoryScene: Identifiable, Hashable {
    public let id: UUID = UUID()
    public let index: Int
    public let text: String
    public let prompt: String
}

// MARK: - Prompt Composer
public struct PromptComposer {
    public struct Options {
        public var style: Style = .illustration
        public var ageBand: AgeBand = .ages4to7
        public var palette: Palette = .warm
        public var includeTitleMotifs: Bool = true
        public var includeTypeMotifs: Bool = true
        public var includeKidNames: Bool = true
        public var extraDescriptors: [String] = []
        public init() {}
    }

    public enum Style: String { case illustration, sketch, animation }
    public enum AgeBand: String { case ages3to5, ages4to7, ages6to9 }
    public enum Palette: String { case warm, pastel, highContrast }

    public init() {}

    public func makePrompt(story: SavedStory, sceneText: String, sceneIndex: Int, options: Options = .init()) -> String {
        let cleanTitle = story.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let names = story.kidNames.joined(separator: ", ")
        let type = story.type.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines: [String] = []
        lines.append("Storybook \(options.style.rawValue) for \(options.ageBand.rawValue).")
        if options.includeTitleMotifs, !cleanTitle.isEmpty { lines.append("Title motif: \(cleanTitle).") }
        if options.includeTypeMotifs, !type.isEmpty { lines.append("Theme: \(type).") }
        if options.includeKidNames, !names.isEmpty { lines.append("Main child names to feature gently: \(names).") }
        lines.append("Scene: \(sceneText).")
        switch options.palette {
        case .warm: lines.append("Warm palette, soft lighting, clean shapes, friendly faces, simple backgrounds.")
        case .pastel: lines.append("Pastel palette, gentle lighting, rounded shapes, friendly faces, uncluttered backgrounds.")
        case .highContrast: lines.append("High-contrast palette, clear silhouettes, bold shapes, excellent readability.")
        }
        lines.append("Readable for kids, no small text, avoid scary imagery, wholesome vibes.")
        if !options.extraDescriptors.isEmpty { lines.append(options.extraDescriptors.joined(separator: ", ")) }
        lines.append("Scene index: #\(sceneIndex).")
        return lines.joined(separator: " ")
    }
}

// MARK: - Scene Extractor
public struct SceneExtractor {
    public struct Options {
        public var maxScenes: Int = 12
        public var minCharsPerScene: Int = 120
        public var maxCharsPerScene: Int = 320
        public var sentenceJoin: Int = 4 // group up to N sentences per scene
        public init() {}
    }

    public init() {}

    public func extractScenes(from story: SavedStory, options: Options = .init(), promptComposer: PromptComposer = .init(), composerOptions: PromptComposer.Options = .init()) -> [StoryScene] {
        let sentences = splitIntoSentences(story.content)
        let groups = groupSentences(sentences,
                                    maxScenes: options.maxScenes,
                                    minChars: options.minCharsPerScene,
                                    maxChars: options.maxCharsPerScene,
                                    join: options.sentenceJoin)
        return groups.enumerated().map { (idx, text) in
            let prompt = promptComposer.makePrompt(story: story, sceneText: text, sceneIndex: idx + 1, options: composerOptions)
            return StoryScene(index: idx + 1, text: text, prompt: prompt)
        }
    }

    // Basic sentence splitter (regex)
    private func splitIntoSentences(_ content: String) -> [String] {
        let pattern = "[^.!?]+[.!?]?"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let ns = content as NSString
        let matches = regex?.matches(in: content, options: [], range: NSRange(location: 0, length: ns.length)) ?? []
        var out: [String] = matches.map { ns.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines) }
        out = out.filter { !$0.isEmpty }
        return out
    }

    private func groupSentences(_ sentences: [String], maxScenes: Int, minChars: Int, maxChars: Int, join: Int) -> [String] {
        guard !sentences.isEmpty else { return [] }
        var scenes: [String] = []
        var i = 0
        while i < sentences.count && scenes.count < maxScenes {
            var chunk = sentences[i]
            var joined = 1
            while i + joined < sentences.count && joined < join && (chunk.count + 1 + sentences[i + joined].count) <= maxChars {
                chunk += " " + sentences[i + joined]
                joined += 1
            }
            if chunk.count < minChars, i + joined < sentences.count {
                chunk += " " + sentences[i + joined]
                joined += 1
            }
            scenes.append(chunk)
            i += max(1, joined)
        }
        return scenes
    }
}

// MARK: - Bridge removed (we now use the SwiftUI Image Playground sheet directly)

// MARK: - SwiftUI list of scenes (per‑scene Generate + image display) (per‑scene Generate + image display)
public struct IllustrationSceneListView: View {
    let story: SavedStory
    let pipeline: IllustrationPipeline

    @State private var scenes: [StoryScene] = []
    @State private var images: [UUID: UIImage] = [:]

    // Paging state
    @State private var currentIndex: Int = 0

    // Image Playground state
    @State private var isImagePlaygroundPresented = false
    @State private var generatedImageURL: URL? = nil
    @State private var showCancellationAlert = false

    public init(story: SavedStory, pipeline: IllustrationPipeline) {
        self.story = story
        self.pipeline = pipeline
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {

                VStack(spacing: 16) {
                    // Title + page indicator (top)
                    HStack {
                        Text(story.title)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(pageIndicator)
                            .font(.footnote).bold()
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.horizontal, 16)

                    // Card carousel
                    let cardWidth = min(geo.size.width * 0.88, 820)
                    let cardHeight = min(geo.size.height * 0.68, 560)

                    TabView(selection: $currentIndex) {
                        ForEach(Array(scenes.enumerated()), id: \.offset) { (idx, scene) in
                            SceneCard(
                                scene: scene,
                                image: images[scene.id],
                                size: CGSize(width: cardWidth, height: cardHeight),
                                onGenerate: {
                                    presentPlaygroundOrFallback(for: scene)
                                }
                            )
                            .tag(idx)
                            .padding(.horizontal, (geo.size.width - cardWidth) / 2)
                            .padding(.vertical, (geo.size.height - cardHeight) / 2 - 30)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(width: geo.size.width, height: cardHeight)

                    // Bottom controls (prev/next)
                    HStack {
                        Button(action: goPrev) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .heavy))
                                .frame(width: 48, height: 48)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                        .opacity(currentIndex == 0 ? 0.4 : 1)

                        Spacer()

                        Button(action: goNext) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .heavy))
                                .frame(width: 48, height: 48)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex >= max(0, scenes.count - 1))
                        .opacity(currentIndex >= max(0, scenes.count - 1) ? 0.4 : 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
            }
        }
        .onAppear {
            scenes = pipeline.extractScenes(story)
            hydrateImagesFromStore()
        }
        .onChange(of: generatedImageURL) { _, url in
            guard let url else { return }
            // Cache & persist to the corresponding scene (current index)
            guard scenes.indices.contains(currentIndex) else { return }
            let scene = scenes[currentIndex]
            if let img = loadUIImage(from: url) {
                images[scene.id] = img
            }
            StoryIllustrationsStore.upsertImage(for: story.id, index: scene.index, imageURL: url)
        }
        .alert("Generation Cancelled", isPresented: $showCancellationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The image generation was cancelled.")
        }
        // Present Apple's Image Playground sheet (when available)
        #if canImport(ImagePlayground)
        .modifier(ImagePlaygroundSheetWrapper(
            isPresented: $isImagePlaygroundPresented,
            conceptProvider: { currentConcept },
            onCompletion: { url in generatedImageURL = url },
            onCancellation: { showCancellationAlert = true }
        ))
        #endif
    }

    // MARK: - Helpers
    private var pageIndicator: String {
        guard !scenes.isEmpty else { return "0/0" }
        return "\(currentIndex + 1)/\(scenes.count)"
    }

    private func goPrev() { currentIndex = max(0, currentIndex - 1) }
    private func goNext() { currentIndex = min(max(0, scenes.count - 1), currentIndex + 1) }

    private func hydrateImagesFromStore() {
        let persisted = StoryIllustrationsStore.load(for: story.id)
        for p in persisted {
            if let url = URL(string: p.imageURL), let img = loadUIImage(from: url) {
                if let sc = scenes.first(where: { $0.index == p.index }) {
                    images[sc.id] = img
                }
            }
        }
    }

    private func loadUIImage(from url: URL) -> UIImage? {
        if url.isFileURL, let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        return nil
    }

    private func presentPlaygroundOrFallback(for scene: StoryScene) {
        #if canImport(ImagePlayground)
        if #available(iOS 18.0, *) {
            isImagePlaygroundPresented = true
            return
        }
        #endif
        // Fallback placeholder
        images[scene.id] = placeholderImage(text: scene.text)
    }

    private func placeholderImage(text: String) -> UIImage {
        let size = CGSize(width: 1024, height: 768)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemTeal.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let para = NSMutableParagraphStyle(); para.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [ .font: UIFont.boldSystemFont(ofSize: 36), .foregroundColor: UIColor.white, .paragraphStyle: para ]
            ("Illustration placeholder\n\n" + String(text.prefix(200))).draw(in: CGRect(x: 40, y: 100, width: size.width - 80, height: size.height - 200), withAttributes: attrs)
        }
    }

    // Current concept from prompt + title for the current page
    #if canImport(ImagePlayground)
    private var currentConcept: ImagePlaygroundConcept? {
        guard scenes.indices.contains(currentIndex) else { return nil }
        let sc = scenes[currentIndex]
        if #available(iOS 18.0, *) {
            return ImagePlaygroundConcept.extracted(from: sc.prompt, title: story.title)
        } else { return nil }
    }
    #endif
}

// MARK: - Card UI
private struct SceneCard: View {
    let scene: StoryScene
    let image: UIImage?
    let size: CGSize
    let onGenerate: () -> Void

    var body: some View {
        ZStack {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Placeholder background
                    LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 10)

            // Center text panel with gradient background
            VStack { Spacer() }
                .frame(width: size.width, height: size.height)
                .overlay(alignment: .bottom) {
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)]),
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: min(180, size.height * 0.36))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                        HStack(alignment: .bottom, spacing: 12) {
                            Text(scene.text)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(4)
                                .padding(14)
                            Spacer()
                            // Small Generate button (wand)
                            Button(action: onGenerate) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(.ultraThickMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 14)
                            .padding(.bottom, 12)
                        }
                    }
                    .frame(width: size.width)
                }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Image Playground SwiftUI wrapper
#if canImport(ImagePlayground)
@available(iOS 18.0, *)
private struct ImagePlaygroundSheetWrapper: ViewModifier {
    @Binding var isPresented: Bool
    var conceptProvider: () -> ImagePlaygroundConcept?
    var onCompletion: (URL) -> Void
    var onCancellation: () -> Void

    func body(content: Content) -> some View {
        if let concept = conceptProvider() {
            content
                .imagePlaygroundSheet(
                    isPresented: $isPresented,
                    concepts: [concept],
                    onCompletion: { url in onCompletion(url) },
                    onCancellation: { onCancellation() }
                )
        } else {
            content
        }
    }
}
#endif

// MARK: - Pipeline facade (no batch)
public struct IllustrationPipeline {
    public var extractScenes: (_ story: SavedStory) -> [StoryScene]

    public init(
        extractor: SceneExtractor = .init(),
        composer: PromptComposer = .init(),
        extractorOptions: SceneExtractor.Options = .init(),
        composerOptions: PromptComposer.Options = .init()
    ) {
        self.extractScenes = { story in
            extractor.extractScenes(from: story, options: extractorOptions, promptComposer: composer, composerOptions: composerOptions)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct IllustrationSceneListView_Previews: PreviewProvider {
    static var sample: SavedStory {
        SavedStory(
            id: UUID().uuidString,
            title: "Moonlake Adventure",
            description: "A calm night voyage",
            content: "On a calm night, Alex folded a paper boat. He placed it on the moonlit lake and whispered, ‘Adventure time!’ Fireflies danced like tiny stars guiding the way. The boat bobbed gently across ripples of silver.",
            date: .now,
            duration: 45,
            type: "Bedtime Adventure",
            kidNames: ["Alex", "Jamie"]
        )
    }
    static var previews: some View {
        IllustrationSceneListView(story: sample, pipeline: IllustrationPipeline())
            .preferredColorScheme(.light)
            .previewDisplayName("Scenes (Per‑scene Generate)")
    }
}
#endif
