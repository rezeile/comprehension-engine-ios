import Foundation
import AVFoundation
import Speech
import Combine

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isSpeaking = false
    @Published var transcriptionText = ""
    @Published var hasTranscript: Bool = false
    @Published var inputLevel: Float = 0 // 0.0 - 1.0 normalized mic level for UI visualizations
    @Published var microphonePermission: AVAudioSession.RecordPermission = .undetermined
    @Published var speechRecognitionPermission: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    // MARK: - Private Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private let elevenLabsAPI = ElevenLabsAPI()
    private let backendAPI = BackendAPI()
    
    private var audioPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var transcriptionBuffer: String = ""
    
    // MARK: - Initialization
    private override init() {
        super.init()
        print("🔍 DEBUG: AudioManager init started")
        
        // Defer heavy operations to avoid crashes during init
        DispatchQueue.main.async { [weak self] in
            self?.setupSpeechRecognition()
            self?.setupAudioSession()
            self?.checkPermissions()
        }
        
        print("🔍 DEBUG: AudioManager init completed")
    }
    
    // MARK: - Setup Methods
    private func setupSpeechRecognition() {
        speechRecognizer?.delegate = self
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func checkPermissions() {
        // Check microphone permission using appropriate API for iOS version
        if #available(iOS 17.0, *) {
            // Use modern iOS 17+ API
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    let permission: AVAudioSession.RecordPermission = granted ? .granted : .denied
                    self?.microphonePermission = permission
                }
            }
        } else {
            // Use legacy API for older iOS versions
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    let permission: AVAudioSession.RecordPermission = granted ? .granted : .denied
                    self?.microphonePermission = permission
                }
            }
        }
        
        // Check speech recognition permission
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.speechRecognitionPermission = status
            }
        }
    }
    
    // MARK: - Speech Recognition
    func startRecording() throws {
        guard !isRecording else { return }
        
        // Reset state
        transcriptionText = ""
        // Do not clear transcriptionBuffer here; it is cleared when finalized
        isRecording = true
        
        // Ensure any ongoing playback is stopped before reconfiguring the session
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        
        // Configure audio session synchronously before installing tap to avoid race conditions
        try configureAudioSession(for: .voiceChat)
        
        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw AudioError.recognitionRequestFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        // Remove any existing tap defensively before installing a new one
        inputNode.removeTap(onBus: 0)
        // Install tap using the node's current native format to avoid format mismatch
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            // Opportunistically derive an input level for UI waveform when float data available
            if let channelData = buffer.floatChannelData?.pointee {
                let frameCount = Int(buffer.frameLength)
                if frameCount > 0 {
                    // Sample sparsely to reduce CPU usage
                    var sumOfSquares: Float = 0
                    var samplesCounted: Int = 0
                    let strideSize = max(1, frameCount / 256)
                    var index = 0
                    while index < frameCount {
                        let sample = channelData[index]
                        sumOfSquares += sample * sample
                        samplesCounted += 1
                        index += strideSize
                    }
                    if samplesCounted > 0 {
                        let rms = sqrt(sumOfSquares / Float(samplesCounted))
                        // Map RMS (~0..~0.1 typical speech) to 0..1 for UI
                        let normalized = min(max(rms * 20.0, 0.0), 1.0)
                        DispatchQueue.main.async { [weak self] in
                            self?.inputLevel = normalized
                        }
                    }
                }
            }
        }
        
        // Start audio engine
        audioEngine.reset()
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    self.transcriptionText = result.bestTranscription.formattedString
                    self.transcriptionBuffer = result.bestTranscription.formattedString
                    self.hasTranscript = !self.transcriptionBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
            
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    self.isRecording = false
                }
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        
        // Stop audio engine and signal end of audio to allow final results
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }

    // MARK: - Transcription Buffer Control
    /// Returns the finalized transcript and clears the internal buffer
    func finalizeTranscription() -> String {
        let finalized = transcriptionBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        transcriptionBuffer = ""
        DispatchQueue.main.async {
            self.transcriptionText = ""
            self.hasTranscript = false
        }
        return finalized
    }
    
    // MARK: - Speech Synthesis
    func speakWithElevenLabs(_ text: String, voiceId: String) async throws {
        guard !isSpeaking else { return }
        
        await MainActor.run { self.isSpeaking = true }
        
        do {
            // Prefer backend TTS if available
            let audioData: Data
            if !BackendAPI().baseURLStringIsEmpty {
                // Try backend first
                do {
                    audioData = try await backendAPI.textToSpeech(text: text, voiceId: voiceId)
                } catch {
                    // Fallback to direct ElevenLabs
                    audioData = try await elevenLabsAPI.generateSpeech(text: text, voiceId: voiceId)
                }
            } else {
                audioData = try await elevenLabsAPI.generateSpeech(text: text, voiceId: voiceId)
            }
            try await playAudioData(audioData)
            await MainActor.run { self.isSpeaking = false }
        } catch {
            print("ElevenLabs TTS failed: \(error)")
            // Allow fallback to acquire speaking lock
            await MainActor.run { self.isSpeaking = false }
            // Fallback to system TTS
            speakWithSystem(text)
        }
    }
    
    func speakWithSystem(_ text: String) {
        guard !isSpeaking else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = true
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
        
        // Monitor completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if let isSpeaking = self?.synthesizer.isSpeaking, !isSpeaking {
                self?.isSpeaking = false
            }
        }
    }

    /// Await until speaking finishes (works for system TTS)
    func waitUntilSpeakingFinished() async {
        while isSpeaking || synthesizer.isSpeaking || (audioPlayer?.isPlaying == true) {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    // MARK: - Audio Playback
    @MainActor
    private func playAudioData(_ audioData: Data) async throws {
        // Configure playback category without defaultToSpeaker to avoid invalid combination errors
        try configureAudioSession(for: .playback)
        
        // Debug: ensure we have non-empty, decodable audio data
        if audioData.isEmpty {
            print("Audio playback error: received empty audio data")
            throw AudioError.audioEngineFailed
        }
        print("🔊 DEBUG: Audio data size=\(audioData.count) bytes")
        
        audioPlayer = try AVAudioPlayer(data: audioData)
        audioPlayer?.delegate = self
        // Ensure the player is ready and volume is audible
        audioPlayer?.prepareToPlay()
        audioPlayer?.volume = 1.0
        audioPlayer?.play()
        
        // Wait for completion
        while audioPlayer?.isPlaying == true {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    // MARK: - Speaking Control
    /// Immediately stops any ongoing speech synthesis or audio playback
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession(for config: AudioSessionConfig) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(config.category, mode: config.mode, options: config.options)
        try audioSession.setActive(true)
    }
    
    // MARK: - Error Handling
    enum AudioError: Error, LocalizedError {
        case recognitionRequestFailed
        case audioEngineFailed
        case permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .recognitionRequestFailed:
                return "Failed to create speech recognition request"
            case .audioEngineFailed:
                return "Failed to start audio engine"
            case .permissionDenied:
                return "Microphone or speech recognition permission denied"
            }
        }
    }
}

// MARK: - Extensions
extension AudioManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        // Handle availability changes
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isSpeaking = false
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isSpeaking = false
        print("Audio playback error: \(error?.localizedDescription ?? "Unknown error")")
    }
}
