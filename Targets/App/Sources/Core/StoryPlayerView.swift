import SwiftUI
import AVFoundation
import SwiftUI
import UIKit

struct StoryPlayerView: View {
    let story: SavedStory
    let duration: Int // Total duration in seconds

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Player state
    @State private var isPlaying = false
    @State private var elapsed: Double = 0
    @State private var timer: Timer? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var wasPlayingBeforeDrag: Bool = false

    // Text-to-Speech properties
    @State private var speechSynthesizer: AVSpeechSynthesizer? = nil
    @State private var currentlySpokenRange: NSRange? = nil
    @State private var sentences: [String] = []

    // Hold a reference to the delegate wrapper to avoid it being deallocated
    @State private var speechDelegateWrapper: SpeechDelegateWrapper? = nil

    private func selectedVoice() -> AVSpeechSynthesisVoice? {
        // Use a cartoon-friendly built-in voice, hardcoded identifier for Samantha or fallback to first English voice
        let cartoonVoiceIdentifier = "com.apple.ttsbundle.Samantha-compact"
        if let voice = AVSpeechSynthesisVoice(identifier: cartoonVoiceIdentifier) {
            return voice
        }
        // fallback: first English voice
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("en") }
    }

    var progress: Double {
        min(elapsed / Double(duration), 1.0)
    }

    var remaining: Int {
        max(duration - Int(elapsed), 0)
    }

    private func angleToElapsed(_ angle: Double) -> Double {
        var normalized = angle / (.pi * 2)
        if normalized < 0 { normalized += 1 }
        return normalized * Double(duration)
    }

    private func elapsedToAngle(_ elapsed: Double) -> Double {
        (elapsed / Double(duration)) * (.pi * 2)
    }

    var body: some View {
        Group {
            NavigationStack {
                ZStack {
                    VStack(spacing: 32) {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: .center) {
                                    // Highlight currently spoken sentence using AttributedString
                                    Text(attributedContent())
                                        .id("storyText")
                                        .font(.system(size: 28, design: .rounded))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(8)
                                        .padding(.horizontal)
                                        .padding(.bottom)
                                }
                            }
                            .mask(
                                LinearGradient(gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.2),
                                    .init(color: .black, location: 0.95),
                                    .init(color: .clear, location: 1)
                                ]), startPoint: .top, endPoint: .bottom)
                            )
                            .onChange(of: elapsed) { newElapsed, _ in
                                // Automatically scroll as playback progresses
                                let totalLines = story.content.components(separatedBy: "\n").count
                                let scrollFraction = CGFloat(newElapsed / Double(duration))
                                _ = scrollFraction * CGFloat(totalLines) * 34  // Approximate line height
                                withAnimation(.linear(duration: 0.8)) {
                                    proxy.scrollTo("storyText", anchor: UnitPoint(x: 0.5, y: scrollFraction))
                                }
                            }
                        }

//                        Spacer(minLength: 0)

                        VStack(spacing: 28) {
//                            Spacer(minLength: 0)
//                                .frame(height: 30)
                            ZStack {
                                let radius: CGFloat = 160
                                let handleSize: CGFloat = 26
                                let angle = .pi * 2 * progress - .pi / 2
                                let handleX = cos(angle) * radius
                                let handleY = sin(angle) * radius

                                // Circular progress ring
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .opacity(0.85)
                                    .animation(.linear(duration: 0.3), value: progress)
                                    .frame(width: 320, height: 320)
                                Circle()
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 14)
                                    .frame(width: 320, height: 320)

                                if progress >= 1.0 {
                                    Circle()
                                        .stroke(Color.yellow.opacity(0.7), lineWidth: 18)
                                        .frame(width: 330, height: 330)
                                        .blur(radius: 8)
                                        .transition(.opacity)
                                        .animation(.easeOut, value: progress)
                                }

                                // Draggable dot
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: handleSize, height: handleSize)
                                    .shadow(radius: 6)
                                    .offset(x: handleX, y: handleY)
                                    .animation(.linear(duration: 0.3), value: elapsed)
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                // Calculate elapsed time based on drag angle without triggering TTS/timer updates immediately
                                                let center = CGPoint(x: 0, y: 0)
                                                let dragPoint = CGPoint(x: value.location.x - center.x, y: value.location.y - center.y)
                                                let dragAngle = atan2(dragPoint.y, dragPoint.x) + .pi / 2
                                                var normalized = dragAngle / (.pi * 2)
                                                if normalized < 0 { normalized += 1 }
                                                // Update elapsed only here as the single source of truth without side effects
                                                self.elapsed = normalized * Double(duration)
                                                // Record current playing state, pause playback visually and logically during drag
                                                if !self.wasPlayingBeforeDrag {
                                                    self.wasPlayingBeforeDrag = self.isPlaying
                                                    HapticEngine.play(.scrub)
                                                }
                                                self.isPlaying = false
                                                // Do NOT sync speech or timer during drag to avoid glitches
                                            }
                                            .onEnded { _ in
                                                // On drag end, sync timer and speech to new elapsed time
                                                // Update speech playback to new position
                                                syncSpeechToElapsed()
                                                HapticEngine.play(.seek)
                                                // Resume playback if was playing before drag
                                                if wasPlayingBeforeDrag {
                                                    isPlaying = true
                                                    startTimer()
                                                    continueSpeech()
                                                }
                                                wasPlayingBeforeDrag = false
                                            }
                                    )

                                // Center: Mascot view with animation and remaining time
                                VStack(spacing: 8) {
                                    DuoLoading()
                                        .padding(.bottom, 8)
                                    Text("Approx \(remaining)s remaining")
                                        .font(.title3.bold())
                                        .foregroundColor(.blue)
                                        .padding(.bottom, 8)
                                }
                            }
                            .padding(.bottom, 40) // More visual separation from the rest
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                    }

                    // Overlay: Play/Pause button centered in the screen
                    Button(action: {
                        // Toggle play/pause and keep timer and TTS in sync with elapsed state
                        isPlaying.toggle()
                        if isPlaying {
                            HapticEngine.play(.play)
                            startTimer()
                            continueSpeech()
                        } else {
                            HapticEngine.play(.pause)
                            stopTimer()
                            pauseSpeech()
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 54, height: 54)
                            .foregroundColor(.blue)
                            .shadow(radius: 6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            HapticEngine.play(.tap)
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .accessibilityLabel("Close")
                    }
                }
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    setupSpeechSynthesizer()
                    splitContentIntoSentences()
                }
                .onDisappear {
                    UIApplication.shared.isIdleTimerDisabled = false
                    stopTimer()
                    stopSpeech()
                }
            }
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 600 : .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(horizontalSizeClass == .regular ? 24 : 0)
        .padding(horizontalSizeClass == .regular ? 24 : 0)
    }

    /// Split the story content into sentences for TTS and highlighting
    func splitContentIntoSentences() {
        // Use a simple approach to separate sentences by ".", "!", "?" followed by space or line end.
        let pattern = #"[^.!?]+[.!?]?"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = story.content as NSString
        var result: [String] = []
        if let matches = regex?.matches(in: story.content, options: [], range: NSRange(location: 0, length: nsString.length)) {
            for match in matches {
                let sentence = nsString.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    result.append(sentence)
                }
            }
        }
        if result.isEmpty {
            // fallback: whole content as one sentence if regex fails
            result = [story.content]
        }
        sentences = result
    }

    /// Setup AVSpeechSynthesizer and assign delegate with closures for updating state
    func setupSpeechSynthesizer() {
        speechSynthesizer = AVSpeechSynthesizer()
        
        // Create delegate wrapper with closures to update state
        let wrapper = SpeechDelegateWrapper(
            onWillSpeakRange: { range, utterance in
                // Instead of mapping to full story content, update elapsed based on utterance progress directly
                let totalLength = utterance.speechString.count
                if totalLength > 0 {
                    let progress = Double(range.location + range.length) / Double(totalLength)
                    let newElapsed = progress * Double(duration)
                    DispatchQueue.main.async {
                        // Only update elapsed if it changed significantly to avoid UI noise
                        if abs(elapsed - newElapsed) > 0.05 {
                            elapsed = min(newElapsed, Double(duration))
                        }
                        currentlySpokenRange = nil // Remove previous highlighting since we highlight based on elapsed only now
                    }
                } else {
                    DispatchQueue.main.async {
                        currentlySpokenRange = nil
                    }
                }
            },
            onDidFinish: {
                DispatchQueue.main.async {
                    currentlySpokenRange = nil
                    isPlaying = false
                    stopTimer()
                    elapsed = Double(duration)
                    HapticEngine.play(.success)
                }
            }
        )
        speechDelegateWrapper = wrapper // Hold reference to prevent deallocation
        speechSynthesizer?.delegate = wrapper
    }

    /// Start speaking the current sentence based on elapsed time
    func speakCurrentSentence() {
        guard let synthesizer = speechSynthesizer else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Determine which sentence to start from based on elapsed
        let elapsedRatio = elapsed / Double(duration)
        let startIndex = min(Int(Double(sentences.count) * elapsedRatio), sentences.count - 1)

        // Update elapsed to the start time of the chosen sentence to keep UI and speech in sync
        let newElapsed = (Double(startIndex) / Double(sentences.count)) * Double(duration)
        DispatchQueue.main.async {
            elapsed = newElapsed
        }

        // Create an utterance starting from startIndex to the end
        let utteranceString = sentences[startIndex...].joined(separator: " ")
        guard !utteranceString.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: utteranceString)
        utterance.voice = selectedVoice()
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.3
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    /// Pause the speech synthesizer
    func pauseSpeech() {
        speechSynthesizer?.pauseSpeaking(at: .immediate)
    }

    /// Continue (resume) speech playback
    func continueSpeech() {
        if let synthesizer = speechSynthesizer {
            if synthesizer.isPaused {
                synthesizer.continueSpeaking()
            } else if !synthesizer.isSpeaking {
                speakCurrentSentence()
            }
        }
    }

    /// Stop speech playback completely
    func stopSpeech() {
        speechSynthesizer?.stopSpeaking(at: .immediate)
        currentlySpokenRange = nil
    }

    /// Sync speech playback to current elapsed time (e.g., after scrubbing or drag ended)
    func syncSpeechToElapsed() {
        guard isPlaying else { return }
        speakCurrentSentence()
    }

    /// Compose an AttributedString with the current sentence highlighted
    func attributedContent() -> AttributedString {
        var attributed = AttributedString(story.content)
        guard let range = currentlySpokenRange else {
            return attributed
        }

        if let swiftRange = Range(range, in: story.content) {
            let start = attributed.index(attributed.startIndex, offsetByCharacters: story.content.distance(from: story.content.startIndex, to: swiftRange.lowerBound))
            let end = attributed.index(attributed.startIndex, offsetByCharacters: story.content.distance(from: story.content.startIndex, to: swiftRange.upperBound))
            let highlightRange = start..<end
            attributed[highlightRange].foregroundColor = .blue
            attributed[highlightRange].font = .system(size: 28, weight: .bold, design: .rounded)
        }
        return attributed
    }

    /// Start the playback timer for updating elapsed time
    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            // Removed automatic increment of elapsed by timer to rely solely on speech delegate updates
            if elapsed >= Double(duration) {
                stopTimer()
                isPlaying = false
                stopSpeech()
            }
        }
    }

    /// Stop the playback timer
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Speech Synthesizer Delegate Wrapper

    /// Wrapper class to act as a delegate and bridge updates back to SwiftUI using closures
    private class SpeechDelegateWrapper: NSObject, AVSpeechSynthesizerDelegate {
        // Closures to update SwiftUI state
        let onWillSpeakRange: (_ characterRange: NSRange, _ utterance: AVSpeechUtterance) -> Void
        let onDidFinish: () -> Void

        init(
            onWillSpeakRange: @escaping (_ characterRange: NSRange, _ utterance: AVSpeechUtterance) -> Void,
            onDidFinish: @escaping () -> Void
        ) {
            self.onWillSpeakRange = onWillSpeakRange
            self.onDidFinish = onDidFinish
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
            DispatchQueue.main.async {
                self.onWillSpeakRange(characterRange, utterance)
            }
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            DispatchQueue.main.async {
                self.onDidFinish()
            }
        }
    }
}


#Preview {
    StoryPlayerView(
        story: SavedStory(
            id: "1",
            title: "Space Adventure",
            description: "A thrilling adventure!",
            content: "Once upon a time, in a galaxy far, far away, there was a young astronaut. He dreamed of exploring the stars! Every night, he gazed up at the sky, wondering what secrets it held. One day, his dream came true.",
            date: .now,
            duration: 30,
            type: "Space Adventure",
            kidNames: ["Alex", "Jamie"]
        ),
        duration: 30
    )
}

