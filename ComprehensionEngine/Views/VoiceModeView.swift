import SwiftUI

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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Voice status indicator
                if featureWaveformEnabled {
                    // Non-breaking additive visualization of input level
                    VoiceWaveformView(level: audioManager.inputLevel,
                                      isRecording: voiceModeState.isRecording,
                                      isSpeaking: voiceModeState.isSpeaking,
                                      isLoading: chatManager.isLoading)
                        .frame(height: 160)
                        .padding(.horizontal)
                } else {
                    VoiceStatusIndicator(
                        isSpeaking: voiceModeState.isSpeaking,
                        isRecording: voiceModeState.isRecording,
                        isLoading: chatManager.isLoading
                    )
                }
                
                Spacer()
                
                // Primary single control (arrow to send, square to stop speaking)
                PrimaryVoiceButton(
                    onSendMessage: sendVoiceMessage,
                    onStopSpeaking: { audioManager.stopSpeaking() },
                    isSpeaking: voiceModeState.isSpeaking,
                    isLoading: chatManager.isLoading,
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
                    ModernIconButton(icon: "xmark", style: .secondary, size: .small) {
                        onClose?()
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
        .onReceive(audioManager.$isRecording) { isRecording in
            voiceModeState.isRecording = isRecording
        }
        .onReceive(audioManager.$isSpeaking) { isSpeaking in
            voiceModeState.isSpeaking = isSpeaking
        }
        .task {
            // Auto-start listening on entry
            do {
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
        // Pause input and finalize transcript
        audioManager.stopRecording()
        let message = audioManager.finalizeTranscription()
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("No speech detected")
            // Resume listening so user can try again
            do { try audioManager.startRecording() } catch { }
            return
        }
        
        Task {
            do {
                let response = try await chatManager.sendMessage(message)
                
                // Auto-play response if enabled
                if voiceSettings.enableElevenLabs {
                    try await audioManager.speakWithElevenLabs(response.content, voiceId: voiceModeState.selectedVoice.id)
                } else {
                    audioManager.speakWithSystem(response.content)
                    await audioManager.waitUntilSpeakingFinished()
                }
                
                // Auto-resume recording
                if voiceAutoResumeAfterReply {
                    try? audioManager.startRecording()
                }
            } catch {
                showError("Failed to send message: \(error.localizedDescription)")
                // Attempt to resume listening even on failure
                try? audioManager.startRecording()
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
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
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
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
        if isRecording {
            return "Listening..."
        } else if isSpeaking {
            return "Speaking..."
        } else if isLoading {
            return "Thinking..."
        } else {
            return "Tap to speak"
        }
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
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if isSpeaking {
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
        .disabled(isLoading || (!isSpeaking && !sendEnabled))
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
                            .animation(AppAnimations.Preset.pulse.speed(1.2).delay(Double(index) * 0.02), value: level)
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
        if isLoading { return AppColors.accent }
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
        if isRecording { return "Listening…" }
        if isSpeaking { return "Speaking…" }
        if isLoading { return "Thinking…" }
        return "Ready and listening"
    }
}

