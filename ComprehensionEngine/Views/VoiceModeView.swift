import SwiftUI
import os

struct VoiceModeView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var chatManager: ChatManager
    let onClose: (() -> Void)?
    @State private var voiceModeState = VoiceModeState()
    @State private var voiceSettings = VoiceSettings.default
    @State private var showingError = false
    @State private var errorMessage = ""
    @AppStorage("feature_waveform_enabled") private var featureWaveformEnabled: Bool = true
    @AppStorage("voice_auto_resume_after_reply") private var voiceAutoResumeAfterReply: Bool = true
    @State private var isSending: Bool = false
    
    // MARK: - Signposting
    private let signposter = OSSignposter(logger: Logger(subsystem: "com.brightspring.ComprehensionEngine", category: "VoiceMode"))
    @State private var viewSignpost: (id: OSSignpostID, state: OSSignpostIntervalState)? = nil
    @State private var sendSignpost: (id: OSSignpostID, state: OSSignpostIntervalState)? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Voice status indicator
                if featureWaveformEnabled {
                    let waveformId = (isSending ? "sending" : (voiceModeState.isSpeaking ? "speaking" : "listening"))
                    VoiceWaveformView(level: (isSending || voiceModeState.isSpeaking) ? 0 : audioManager.inputLevel,
                                      isRecording: voiceModeState.isRecording,
                                      isSpeaking: voiceModeState.isSpeaking,
                                      isLoading: (isSending || chatManager.isLoading),
                                      animateBars: !isSending && voiceModeState.isRecording)
                        .id(waveformId)
                        .frame(height: 160)
                        .padding(.horizontal)
                } else {
                    VoiceStatusIndicator(
                        isSpeaking: voiceModeState.isSpeaking,
                        isRecording: voiceModeState.isRecording,
                        isLoading: (isSending || chatManager.isLoading)
                    )
                }
                
                Spacer()
                
                // Primary single control (arrow to send, square to stop speaking)
                PrimaryVoiceButton(
                    onSendMessage: {
                        startSendSignpost()
                        sendVoiceMessage()
                    },
                    onStopSpeaking: {
                        signposter.emitEvent("voice.stop_tap")
                        audioManager.stopSpeaking()
                    },
                    isSpeaking: voiceModeState.isSpeaking,
                    isLoading: (isSending || chatManager.isLoading),
                    sendEnabled: audioManager.hasTranscript
                )
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                if voiceModeState.isSpeaking {
                    audioManager.stopSpeaking()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                LinearGradient(
                    colors: [AppColors.background.opacity(0.98), AppColors.background.opacity(0.9)],
                    startPoint: .top, endPoint: .bottom
                ), for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { onClose?() }) {
                        ZStack {
                            // Circular, high-contrast tap target with subtle border and shadow
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)

                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(.label))
                        }
                        .contentShape(Circle())
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if viewSignpost == nil {
                let id = signposter.makeSignpostID()
                let st = signposter.beginInterval("voice.view_visible", id: id)
                viewSignpost = (id, st)
                signposter.emitEvent("voice.view_appear")
            }
        }
        .onDisappear {
            if let sp = viewSignpost {
                signposter.emitEvent("voice.view_disappear")
                signposter.endInterval("voice.view_visible", sp.state)
                viewSignpost = nil
            }
            // Persist any unsent transcript as a local user message so it shows in chat after exit
            let draft = audioManager.finalizeTranscription()
            if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task { @MainActor in
                    chatManager.appendLocalUserMessage(draft)
                }
            }
        }
        .onReceive(audioManager.$isRecording) { isRecording in
            voiceModeState.isRecording = isRecording
            signposter.emitEvent(isRecording ? "voice.recording_true" : "voice.recording_false")
        }
        .onReceive(audioManager.$isSpeaking) { isSpeaking in
            voiceModeState.isSpeaking = isSpeaking
            // As soon as speaking begins, exit sending/loading state so UI shows "Speaking..."
            if isSpeaking {
                isSending = false
                chatManager.isLoading = false
            }
            signposter.emitEvent(isSpeaking ? "voice.speaking_true" : "voice.speaking_false")
        }
        .task {
            // Auto-start listening on entry
            do {
                signposter.emitEvent("voice.autostart_recording")
                try audioManager.startRecording()
            } catch {
                showError("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }
    
    private func startVoiceInput() {
        do {
            try audioManager.startRecording()
        } catch {
            showError("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    private func stopVoiceInput() {
        audioManager.stopRecording()
    }
    
    private func sendVoiceMessage() {
        // ⏱️ LATENCY: user tapped send to submit STT transcript
        print("⏱️ LATENCY [voice] user_tapped_send: \(Date().timeIntervalSince1970)")
        signposter.emitEvent("voice.send_tap")
        // Pause input and finalize transcript
        print("🔍 DEBUG [voice]: sendVoiceMessage -> stopRecording")
        audioManager.stopRecording()
        // Immediately reflect UI state for waveform/status
        voiceModeState.isRecording = false
        isSending = true
        chatManager.isLoading = true
        let message = audioManager.finalizeTranscription()
        print("🔍 DEBUG [voice]: sendVoiceMessage -> finalized transcript length=\(message.count)")
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            signposter.emitEvent("voice.send_empty")
            showError("No speech detected")
            // Resume listening so user can try again
            do { try audioManager.startRecording() } catch { }
            endSendSignpost(success: false)
            return
        }
        
        Task {
            do {
                print("🔍 DEBUG [voice]: sendVoiceMessage -> sending to backend; autoPlay=\(voiceSettings.autoPlayResponse)")
                signposter.emitEvent("voice.sending")
                let response = try await chatManager.sendMessage(message)
                print("🔍 DEBUG [voice]: sendVoiceMessage -> backend responded; content length=\(response.content.count)")
                signposter.emitEvent("voice.sent_success")
                
                // Auto-play response using backend TTS (preferred)
                if voiceSettings.autoPlayResponse {
                    do {
                        print("🔍 DEBUG [voice]: sendVoiceMessage -> invoking speakWithElevenLabs voiceId=\(voiceModeState.selectedVoice.id)")
                        try await audioManager.speakWithElevenLabs(response.content, voiceId: voiceModeState.selectedVoice.id)
                        print("🔍 DEBUG [voice]: sendVoiceMessage -> speakWithElevenLabs finished")
                    } catch {
                        print("🔍 DEBUG [voice]: speakWithElevenLabs error=\(error.localizedDescription). Falling back to system TTS")
                        // Fallback to system TTS on error
                        audioManager.speakWithSystem(response.content)
                        await audioManager.waitUntilSpeakingFinished()
                    }
                }
                signposter.emitEvent("voice.reply_spoken")
                
                // Auto-resume recording
                if voiceAutoResumeAfterReply {
                    print("🔍 DEBUG [voice]: sendVoiceMessage -> autoresume recording")
                    signposter.emitEvent("voice.autoresume_recording")
                    try? audioManager.startRecording()
                }
                await MainActor.run {
                    chatManager.isLoading = false
                    isSending = false
                }
                endSendSignpost(success: true)
            } catch {
                print("🔍 DEBUG [voice]: sendVoiceMessage error=\(error.localizedDescription)")
                showError("Failed to send message: \(error.localizedDescription)")
                // Attempt to resume listening even on failure
                try? audioManager.startRecording()
                signposter.emitEvent("voice.send_failed")
                await MainActor.run {
                    chatManager.isLoading = false
                    isSending = false
                }
                endSendSignpost(success: false)
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        signposter.emitEvent("voice.error_shown")
    }

    private func startSendSignpost() {
        if sendSignpost == nil {
            let id = signposter.makeSignpostID()
            let st = signposter.beginInterval("voice.send_cycle", id: id)
            sendSignpost = (id, st)
        }
    }
    private func endSendSignpost(success: Bool) {
        if let sp = sendSignpost {
            signposter.emitEvent(success ? "voice.send_cycle_success" : "voice.send_cycle_fail")
            signposter.endInterval("voice.send_cycle", sp.state)
            sendSignpost = nil
        }
    }
}

struct VoiceStatusIndicator: View {
    let isSpeaking: Bool
    let isRecording: Bool
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Main status circle
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 120, height: 120)
                    .scaleEffect(statusScale)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRecording || isSpeaking)
                
                if isRecording {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                } else if isSpeaking {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "mic")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            
            // Status text
            Text(statusText)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    private var statusColor: Color {
        if isRecording {
            return .red
        } else if isSpeaking {
            return .blue
        } else if isLoading {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var statusScale: CGFloat {
        if isRecording || isSpeaking {
            return 1.1
        } else {
            return 1.0
        }
    }
    
    private var statusText: String {
        if isRecording { return "Listening..." }
        if isLoading { return "Thinking..." }
        if isSpeaking { return "Speaking..." }
        return "Listening..." 
    }
}

struct TranscriptionDisplay: View {
    let text: String
    let isSpeaking: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            if !text.isEmpty {
                Text("You said:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: text)
    }
}

struct PrimaryVoiceButton: View {
    let onSendMessage: () -> Void
    let onStopSpeaking: () -> Void
    let isSpeaking: Bool
    let isLoading: Bool
    let sendEnabled: Bool
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 80, height: 80)
                if isSpeaking || isLoading {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(sendEnabled ? .white : .gray)
                }
            }
        }
        .disabled((!isSpeaking && !sendEnabled) || isLoading)
        .accessibilityLabel(isSpeaking ? "Stop speaking" : "Send")
    }
    
    private func action() {
        if isLoading { return }
        if isSpeaking {
            onStopSpeaking()
        } else if sendEnabled {
            onSendMessage()
        }
    }
}

#if DEBUG
#Preview {
    VoiceModeView(onClose: {})
        .environmentObject(AudioManager.shared)
        .environmentObject(ChatManager.shared)
}
#endif

// MARK: - Additive Waveform View (non-breaking)
struct VoiceWaveformView: View {
    let level: Float // 0..1
    let isRecording: Bool
    let isSpeaking: Bool
    let isLoading: Bool
    let animateBars: Bool
    
    
    private let barCount = 24
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.systemGray5, lineWidth: 1)
                    )
                    .shadow(AppSpacing.Shadow.small)
                
                HStack(alignment: .center, spacing: 4) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(barColor)
                            .frame(width: 6, height: barHeight(for: index))
                            .animation(animateBars ? AppAnimations.Preset.pulse.speed(1.2).delay(Double(index) * 0.02) : .linear(duration: 0), value: level)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            
            Text(statusText)
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private var barColor: Color {
        if isRecording { return .red }
        if isSpeaking { return AppColors.primary }
        return AppColors.systemGray3
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        // Create a soft moving mountain using the current level as an amplitude
        let normalizedIndex = Double(index) / Double(barCount - 1)
        let envelope = sin(normalizedIndex * .pi)
        let base: CGFloat = 12
        let amplitude: CGFloat = CGFloat(level) * 60
        return base + CGFloat(envelope) * amplitude
    }
    
    private var statusText: String {
        if isRecording { return "Listening..." }
        if isLoading { return "Thinking..." }
        if isSpeaking { return "Speaking..." }
        return "Listening..."
    }
}

// (SpeakingBackdropView removed)

