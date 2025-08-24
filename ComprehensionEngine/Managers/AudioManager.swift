import Foundation
import AVFoundation
import Speech
import Combine
import os

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
    private let backendAPI = BackendAPI()
    
    private var audioPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var transcriptionBuffer: String = ""
    
    // MARK: - Signposting
    private let audioLogger = Logger(subsystem: "com.brightspring.ComprehensionEngine", category: "Audio")
    private lazy var signposter = OSSignposter(logger: audioLogger)
    private var recordingSignpost: (id: OSSignpostID, state: OSSignpostIntervalState)?
    private var ttsSignpost: (id: OSSignpostID, state: OSSignpostIntervalState)?
    private var playbackSignpost: (id: OSSignpostID, state: OSSignpostIntervalState)?
    private var streamSignpost: (id: OSSignpostID, state: OSSignpostIntervalState)?
    
    // MARK: - Streaming Playback (voice_chat)
    private let streamingQueue = DispatchQueue(label: "ce.audio.streaming.queue")
    private var streamingEngine: AVAudioEngine?
    private var streamingPlayer: AVAudioPlayerNode?
    private var streamingFormat: AVAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
    private var streamingTask: URLSessionDataTask?
    private var pcmResidual: Data = Data()
    private var lastAppendAt: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var lastLevelUpdateAt: CFAbsoluteTime = 0
    private let levelUpdateThrottle: CFTimeInterval = 1.0 / 20.0 // ~20 Hz throttle to reduce UI churn
    private var lastPublishedLevel: Float = 0
    private let minLevelDeltaToPublish: Float = 0.03 // only publish if level changes meaningfully
    
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
        // Signpost: recording begin
        let recId = signposter.makeSignpostID()
        let recState = signposter.beginInterval("audio.recording", id: recId)
        recordingSignpost = (recId, recState)
        signposter.emitEvent("audio.recording_start")
        
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
                        let now = CFAbsoluteTimeGetCurrent()
                        if let strongSelf = self,
                           now - strongSelf.lastLevelUpdateAt >= strongSelf.levelUpdateThrottle,
                           abs(normalized - strongSelf.lastPublishedLevel) >= strongSelf.minLevelDeltaToPublish {
                            strongSelf.lastLevelUpdateAt = now
                            strongSelf.lastPublishedLevel = normalized
                            DispatchQueue.main.async { [weak self] in
                                self?.inputLevel = normalized
                            }
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
                // Clean up recognition pipeline after completion or error
                self.teardownRecognition()
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
        // Ensure recognition task/request do not linger
        teardownRecognition()
        // Settle waveform immediately
        DispatchQueue.main.async { [weak self] in
            self?.inputLevel = 0
        }
        // Signpost: recording end
        signposter.emitEvent("audio.recording_stop")
        if let rec = recordingSignpost {
            signposter.endInterval("audio.recording", rec.state)
            recordingSignpost = nil
        }
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
    /// Preferred path: fetch audio from backend `/api/tts` (which uses ElevenLabs server-side)
    /// Falls back to system TTS if backend TTS fails or is unavailable.
    func speakWithElevenLabs(_ text: String, voiceId: String) async throws {
        guard !isSpeaking else { return }
        
        // Signpost: TTS request lifecycle
        let ttsId = signposter.makeSignpostID()
        let ttsState = signposter.beginInterval("audio.tts_request", id: ttsId)
        ttsSignpost = (ttsId, ttsState)
        signposter.emitEvent("audio.tts_request_start")
        defer {
            signposter.endInterval("audio.tts_request", ttsState)
            ttsSignpost = nil
        }
        
        do {
            // Request audio from backend
            let _ttsStart = Date().timeIntervalSince1970
            print("⏱️ LATENCY [voice] tts_request_start: source=backend ts=\(_ttsStart)")
            let audioData = try await backendAPI.textToSpeech(text: text, voiceId: voiceId)
            let _ttsEnd = Date().timeIntervalSince1970
            print("⏱️ LATENCY [voice] tts_request_end: source=backend ts=\(_ttsEnd) delta=\(_ttsEnd - _ttsStart)s size=\(audioData.count)B")
            signposter.emitEvent("audio.tts_backend_success")
            try await playAudioData(audioData)
            await MainActor.run { self.isSpeaking = false }
        } catch {
            print("Backend TTS failed: \(error.localizedDescription)")
            signposter.emitEvent("audio.tts_backend_failed")
            // Fallback to system TTS
            await MainActor.run { self.isSpeaking = false }
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
    
    // MARK: - Recognition Cleanup
    private func teardownRecognition() {
        if let task = recognitionTask {
            task.cancel()
        }
        recognitionTask = nil
        recognitionRequest = nil
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
        
        // Signpost: playback lifecycle
        let pbId = signposter.makeSignpostID()
        let pbState = signposter.beginInterval("audio.playback", id: pbId)
        playbackSignpost = (pbId, pbState)
        signposter.emitEvent("audio.playback_start")

        audioPlayer = try AVAudioPlayer(data: audioData)
        audioPlayer?.delegate = self
        // Ensure the player is ready and volume is audible
        audioPlayer?.prepareToPlay()
        audioPlayer?.volume = 1.0
        // ⏱️ LATENCY: eleven labs first starts speaking (at play start)
        print("⏱️ LATENCY [voice] tts_play_start: \(Date().timeIntervalSince1970)")
        // Mark speaking precisely at play start so UI text aligns with first audio
        self.isSpeaking = true
        audioPlayer?.play()
        
        // Wait for completion
        while audioPlayer?.isPlaying == true {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        signposter.emitEvent("audio.playback_end")
        signposter.endInterval("audio.playback", pbState)
        playbackSignpost = nil
    }
    
    // MARK: - Streaming voice_chat
    /// Start streaming voice chat audio from backend and play via AVAudioEngine + AVAudioPlayerNode
    func startStreamingVoiceChat(message: String, voiceId: String, conversationId: String?) {
        // Stop any existing speaking/streams first
        cancelStreamingPlayback()
        if isRecording {
            stopRecording()
        }
        
        // Switch to playback session
        do { try configureAudioSession(for: .playback) } catch { }
        
        // Lazily set up engine/player
        setupStreamingEngineIfNeeded()
        guard let engine = streamingEngine, let player = streamingPlayer else { return }
        
        // Reset residuals
        pcmResidual.removeAll(keepingCapacity: true)
        lastAppendAt = CFAbsoluteTimeGetCurrent()
        // Signpost: voice chat stream begin
        let streamId = signposter.makeSignpostID()
        let streamState = signposter.beginInterval("audio.voice_chat_stream", id: streamId)
        streamSignpost = (streamId, streamState)
        signposter.emitEvent("audio.voice_chat_stream_start")
        
        // Kick off HTTP streaming
        do {
            let task = try backendAPI.startVoiceChatStream(
                message: message,
                voiceId: voiceId,
                conversationId: conversationId,
                acceptMimeType: "audio/pcm",
                onFirstByte: { [weak self] in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.isSpeaking = true
                        if !engine.isRunning {
                            do { try engine.start() } catch { }
                        }
                        if !player.isPlaying {
                            player.play()
                        }
                        print("⏱️ LATENCY [voice] voice_chat_first_byte: \(Date().timeIntervalSince1970)")
                        self.signposter.emitEvent("audio.voice_chat_first_byte")
                    }
                },
                onBytes: { [weak self] chunk in
                    guard let self = self else { return }
                    self.streamingQueue.async {
                        self.feedPCMData(chunk)
                    }
                },
                onComplete: { [weak self] in
                    guard let self = self else { return }
                    self.streamingQueue.async {
                        self.flushResidualIfAny()
                        self.scheduleStopIfQuiescent(delay: 0.4)
                    }
                    self.streamingTask = nil
                    self.signposter.emitEvent("audio.voice_chat_stream_complete")
                    if let sp = self.streamSignpost {
                        self.signposter.endInterval("audio.voice_chat_stream", sp.state)
                        self.streamSignpost = nil
                    }
                },
                onError: { [weak self] error in
                    print("voice_chat stream error: \(error.localizedDescription)")
                    self?.cancelStreamingPlayback()
                    self?.signposter.emitEvent("audio.voice_chat_stream_error")
                }
            )
            streamingTask = task
        } catch {
            print("Failed to start voice_chat stream: \(error)")
            signposter.emitEvent("audio.voice_chat_stream_failed_to_start")
        }
    }
    
    /// Cancel the in-flight voice_chat stream and stop playback immediately
    func cancelStreamingPlayback() {
        streamingTask?.cancel()
        streamingTask = nil
        streamingQueue.sync {
            pcmResidual.removeAll(keepingCapacity: false)
        }
        teardownStreaming()
        // Signpost: end stream if active
        if let sp = streamSignpost {
            signposter.emitEvent("audio.voice_chat_stream_cancel")
            signposter.endInterval("audio.voice_chat_stream", sp.state)
            streamSignpost = nil
        }
    }
    
    // MARK: - Streaming internals
    private func setupStreamingEngineIfNeeded() {
        if streamingEngine == nil {
            streamingEngine = AVAudioEngine()
        }
        if streamingPlayer == nil {
            streamingPlayer = AVAudioPlayerNode()
        }
        guard let engine = streamingEngine, let player = streamingPlayer else { return }
        if player.engine == nil {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: streamingFormat)
            do { try engine.start() } catch { }
        }
    }
    
    private func feedPCMData(_ data: Data) {
        // Ensure even number of bytes (16-bit samples)
        var combined = Data()
        combined.reserveCapacity(pcmResidual.count + data.count)
        if !pcmResidual.isEmpty { combined.append(pcmResidual) }
        combined.append(data)
        let totalBytes = combined.count
        let usableBytes = (totalBytes / 2) * 2
        let leftover = totalBytes - usableBytes
        if leftover > 0 {
            pcmResidual = combined.suffix(leftover)
        } else {
            pcmResidual.removeAll(keepingCapacity: true)
        }
        guard usableBytes > 0 else { return }
        let pcmChunk = combined.prefix(usableBytes)
        
        // Convert 16-bit little-endian PCM to float32 [-1, 1]
        let sampleCount = usableBytes / 2
        let frames = AVAudioFrameCount(sampleCount)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: streamingFormat, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?.pointee else { return }
        pcmChunk.withUnsafeBytes { rawPtr in
            let int16Ptr = rawPtr.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                let s = Int16(littleEndian: int16Ptr[i])
                channel[i] = max(-1.0, min(1.0, Float(s) / 32768.0))
            }
        }
        
        streamingPlayer?.scheduleBuffer(buffer, completionHandler: nil)
        lastAppendAt = CFAbsoluteTimeGetCurrent()
    }
    
    private func flushResidualIfAny() {
        if !pcmResidual.isEmpty {
            feedPCMData(Data()) // forces flush logic; will no-op if residual < 2 bytes
        }
    }
    
    private func scheduleStopIfQuiescent(delay: TimeInterval) {
        let deadline = DispatchTime.now() + delay
        streamingQueue.asyncAfter(deadline: deadline) { [weak self] in
            guard let self = self else { return }
            let now = CFAbsoluteTimeGetCurrent()
            if now - self.lastAppendAt >= delay {
                self.teardownStreaming()
            } else {
                // Data arrived after scheduling; check again shortly
                self.scheduleStopIfQuiescent(delay: delay)
            }
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

    // MARK: - Streaming teardown
    private func teardownStreaming() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let player = self.streamingPlayer, player.isPlaying {
                player.stop()
            }
            if let engine = self.streamingEngine, engine.isRunning {
                engine.stop()
            }
            self.streamingPlayer = nil
            self.streamingEngine = nil
            self.isSpeaking = false
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
        audioPlayer = nil
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isSpeaking = false
        print("Audio playback error: \(error?.localizedDescription ?? "Unknown error")")
        audioPlayer = nil
    }
}
