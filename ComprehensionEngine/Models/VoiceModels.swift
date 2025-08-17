import Foundation
import AVFoundation

struct Voice: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let description: String
    let previewURL: String?
    
    static let defaultVoices: [Voice] = [
        Voice(id: "21m00Tcm4TlvDq8ikWAM", name: "Rachel", category: "Female", description: "Professional and warm", previewURL: nil),
        Voice(id: "AZnzlk1XvdvUeBnXmlld", name: "Domi", category: "Female", description: "Strong and confident", previewURL: nil),
        Voice(id: "EXAVITQu4vr4xnSDxMaL", name: "Bella", category: "Female", description: "Soft and friendly", previewURL: nil),
        Voice(id: "ErXwobaYiN1PXXYv6Ewj", name: "Josh", category: "Male", description: "Deep and authoritative", previewURL: nil),
        Voice(id: "TxGEqnHWrfWFTfGW9XjX", name: "Arnold", category: "Male", description: "Strong and energetic", previewURL: nil)
    ]
}

class VoiceModeState: ObservableObject {
    @Published var isVoiceMode: Bool = false
    @Published var transcriptionText: String = ""
    @Published var isRecording: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var isAudioSettling: Bool = false
    @Published var isInCooldown: Bool = false
    @Published var selectedVoice: Voice = Voice.defaultVoices[0]
}

struct VoiceSettings: Codable {
    var selectedVoiceId: String = "21m00Tcm4TlvDq8ikWAM"
    var speechRate: Float = 1.0
    var enableElevenLabs: Bool = true
    var enableSystemTTS: Bool = true
    var autoPlayResponse: Bool = true
    var voiceActivation: Bool = false
    
    static let `default` = VoiceSettings()
}

struct AudioSessionConfig {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
    
    static let voiceChat = AudioSessionConfig(
        category: .playAndRecord,
        mode: .voiceChat,
        options: [.defaultToSpeaker, .allowBluetooth]
    )
    
    static let playback = AudioSessionConfig(
        category: .playback,
        mode: .default,
        options: []
    )
}
