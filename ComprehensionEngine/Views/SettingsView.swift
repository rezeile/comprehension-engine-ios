import SwiftUI
import AVFoundation
import Speech

struct SettingsView: View {
    @EnvironmentObject var audioManager: AudioManager
    @State private var voiceSettings = VoiceSettings.default
    @State private var showingVoicePicker = false
    @State private var availableVoices: [Voice] = Voice.defaultVoices
    @AppStorage("feature_waveform_enabled") private var featureWaveformEnabled: Bool = true
    
    var body: some View {
        NavigationView {
            Form {
                // Voice Settings Section
                Section("Voice Settings") {
                    // Voice Selection
                    HStack {
                        Text("Voice")
                        Spacer()
                        Button(voiceSettings.selectedVoiceId.isEmpty ? "Select Voice" : getVoiceName(for: voiceSettings.selectedVoiceId)) {
                            showingVoicePicker = true
                        }
                        .foregroundColor(.blue)
                    }
                    
                    // Speech Rate
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speech Rate")
                            Spacer()
                            Text("\(Int(voiceSettings.speechRate * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $voiceSettings.speechRate, in: 0.5...2.0, step: 0.1)
                    }
                    
                    // ElevenLabs Toggle
                    Toggle("Use ElevenLabs TTS", isOn: $voiceSettings.enableElevenLabs)
                    
                    // System TTS Toggle
                    Toggle("Use System TTS", isOn: $voiceSettings.enableSystemTTS)
                    
                    // Auto-play Response
                    Toggle("Auto-play Responses", isOn: $voiceSettings.autoPlayResponse)
                    
                    // Voice Activation
                    Toggle("Voice Activation", isOn: $voiceSettings.voiceActivation)

                    // Experimental: Input Waveform Visualization
                    Toggle("Show Input Waveform (Experimental)", isOn: $featureWaveformEnabled)
                }
                
                // Permissions Section
                Section("Permissions") {
                    // Microphone Permission
                    HStack {
                        Text("Microphone")
                        Spacer()
                        PermissionStatusView(status: audioManager.microphonePermission)
                    }
                    
                    // Speech Recognition Permission
                    HStack {
                        Text("Speech Recognition")
                        Spacer()
                        PermissionStatusView(status: audioManager.speechRecognitionPermission)
                    }
                }
                
                // API Keys Section
                Section("API Configuration") {
                    HStack {
                        Text("Anthropic API Key")
                        Spacer()
                        Text(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false ? "✓" : "✗")
                            .foregroundColor(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false ? .green : .red)
                    }
                    
                    HStack {
                        Text("ElevenLabs API Key")
                        Spacer()
                        Text(ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"]?.isEmpty == false ? "✓" : "✗")
                            .foregroundColor(ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"]?.isEmpty == false ? .green : .red)
                    }
                }
                
                // App Info Section
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingVoicePicker) {
                VoicePickerView(
                    selectedVoiceId: $voiceSettings.selectedVoiceId,
                    availableVoices: availableVoices
                )
            }
            .onAppear {
                loadAvailableVoices()
            }
        }
    }
    
    private func getVoiceName(for voiceId: String) -> String {
        return availableVoices.first { $0.id == voiceId }?.name ?? "Unknown Voice"
    }
    
    private func loadAvailableVoices() {
        // In a real app, you would fetch this from ElevenLabs API
        // For now, we'll use the default voices
        availableVoices = Voice.defaultVoices
    }
}

struct PermissionStatusView: View {
    let status: Any
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        if let recordPermission = status as? AVAudioSession.RecordPermission {
            switch recordPermission {
            case .granted:
                return .green
            case .denied:
                return .red
            case .undetermined:
                return .orange
            @unknown default:
                return .gray
            }
        } else if let speechPermission = status as? SFSpeechRecognizerAuthorizationStatus {
            switch speechPermission {
            case .authorized:
                return .green
            case .denied, .restricted:
                return .red
            case .notDetermined:
                return .orange
            @unknown default:
                return .gray
            }
        }
        return .gray
    }
    
    private var statusText: String {
        if let recordPermission = status as? AVAudioSession.RecordPermission {
            switch recordPermission {
            case .granted:
                return "Granted"
            case .denied:
                return "Denied"
            case .undetermined:
                return "Not Determined"
            @unknown default:
                return "Unknown"
            }
        } else if let speechPermission = status as? SFSpeechRecognizerAuthorizationStatus {
            switch speechPermission {
            case .authorized:
                return "Authorized"
            case .denied:
                return "Denied"
            case .restricted:
                return "Restricted"
            case .notDetermined:
                return "Not Determined"
            @unknown default:
                return "Unknown"
            }
        }
        return "Unknown"
    }
}

struct VoicePickerView: View {
    @Binding var selectedVoiceId: String
    let availableVoices: [Voice]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(availableVoices) { voice in
                Button(action: {
                    selectedVoiceId = voice.id
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(voice.name)
                                .font(.headline)
                            
                            Text(voice.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedVoiceId == voice.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AudioManager.shared)
}
