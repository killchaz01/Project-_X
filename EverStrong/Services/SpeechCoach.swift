import AVFoundation

/// Reads coaching cues aloud so people don't have to squint at the screen mid-exercise.
@MainActor
final class SpeechCoach {
    static let shared = SpeechCoach()
    private let synthesizer = AVSpeechSynthesizer()

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppSettings.spokenCoaching) as? Bool ?? true
    }

    func say(_ text: String, interrupt: Bool = false) {
        guard isEnabled else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        if interrupt { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9   // a little slower, easier to follow
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
