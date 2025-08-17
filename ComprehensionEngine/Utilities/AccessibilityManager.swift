import SwiftUI

// MARK: - Accessibility Manager
struct AppAccessibility {
    
    // MARK: - VoiceOver Labels
    struct VoiceOver {
        // Chat
        static let newChat = "Start a new chat"
        static let sendMessage = "Send message"
        static let voiceMode = "Switch to voice mode"
        static let messageFromUser = "Message from you"
        static let messageFromAI = "Message from Claude"
        static let typingIndicator = "Claude is typing"
        static let loadingIndicator = "Loading, please wait"
        
        // Navigation
        static let backButton = "Go back"
        static let settingsButton = "Open settings"
        static let chatTab = "Chat tab"
        static let voiceTab = "Voice mode tab"
        static let settingsTab = "Settings tab"
        
        // Input
        static let textInput = "Type your message"
        static let voiceInput = "Record voice message"
        static let attachmentButton = "Add attachment"
        static let emojiButton = "Add emoji"
        
        // Actions
        static let confirmAction = "Confirm action"
        static let cancelAction = "Cancel action"
        static let deleteAction = "Delete item"
        static let editAction = "Edit item"
    }
    
    // MARK: - Hints
    struct Hints {
        static let dragToDismiss = "Drag down to dismiss keyboard"
        static let doubleTapToEdit = "Double tap to edit message"
        static let longPressForOptions = "Long press for more options"
        static let swipeToDelete = "Swipe left to delete"
        static let tapToFocus = "Tap to focus input field"
    }
    
    // MARK: - Traits
    struct Traits {
        static let button: AccessibilityTraits = .isButton
        static let header: AccessibilityTraits = .isHeader
        static let link: AccessibilityTraits = .isLink
        static let searchField: AccessibilityTraits = .isSearchField
        static let image: AccessibilityTraits = .isImage
        static let selected: AccessibilityTraits = .isSelected
    }
}

// MARK: - Accessibility Extensions
extension View {
    
    // MARK: - Chat Accessibility
    func chatMessageAccessibility(isFromUser: Bool, content: String) -> some View {
        let label = isFromUser ? AppAccessibility.VoiceOver.messageFromUser : AppAccessibility.VoiceOver.messageFromAI
        return self
            .accessibilityLabel(label)
            .accessibilityValue(content)
    }
    
    func newChatButtonAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.newChat)
            .accessibilityHint(AppAccessibility.Hints.tapToFocus)
            .accessibilityAddTraits(AppAccessibility.Traits.button)
    }
    
    func sendButtonAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.sendMessage)
            .accessibilityHint(AppAccessibility.Hints.tapToFocus)
            .accessibilityAddTraits(AppAccessibility.Traits.button)
    }
    
    func voiceModeButtonAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.voiceMode)
            .accessibilityHint(AppAccessibility.Hints.tapToFocus)
        	.accessibilityAddTraits(AppAccessibility.Traits.button)
    }
    
    // MARK: - Input Accessibility
    func textInputAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.textInput)
            .accessibilityHint(AppAccessibility.Hints.tapToFocus)
    }
    
    func voiceInputAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.voiceInput)
            .accessibilityHint(AppAccessibility.Hints.longPressForOptions)
            .accessibilityAddTraits(AppAccessibility.Traits.button)
    }
    
    // MARK: - Navigation Accessibility
    func backButtonAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.backButton)
            .accessibilityAddTraits(AppAccessibility.Traits.button)
    }
    
    func settingsButtonAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.settingsButton)
            .accessibilityAddTraits(AppAccessibility.Traits.button)
    }
    
    // MARK: - Tab Accessibility
    func chatTabAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.chatTab)
            .accessibilityAddTraits(AppAccessibility.Traits.button)
    }
    
    func voiceTabAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.voiceTab)
            .accessibilityAddTraits(AppAccessibility.Traits.button)
    }
    
    func settingsTabAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.settingsTab)
            .accessibilityAddTraits(AppAccessibility.Traits.button)
    }
    
    // MARK: - Loading Accessibility
    func loadingAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.loadingIndicator)
            .accessibilityAddTraits(AppAccessibility.Traits.image)
    }
    
    func typingAccessibility() -> some View {
        self
            .accessibilityLabel(AppAccessibility.VoiceOver.typingIndicator)
            .accessibilityAddTraits(AppAccessibility.Traits.image)
    }
}

// MARK: - Accessibility Modifiers
struct AccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits?
    let value: String?
    
    init(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits? = nil,
        value: String? = nil
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
        self.value = value
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .modifyIf(traits != nil) { view in
                view.accessibilityAddTraits(traits!)
            }
            .modifyIf(hint != nil) { view in
                view.accessibilityHint(hint!)
            }
            .modifyIf(value != nil) { view in
                view.accessibilityValue(value!)
            }
    }
}

// MARK: - Conditional Modifier
extension View {
    @ViewBuilder
    func modifyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Accessibility Button
struct AccessibilityButton: View {
    let title: String
    let hint: String?
    let action: () -> Void
    
    init(
        _ title: String,
        hint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.hint = hint
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .modifier(AccessibilityModifier(
            label: title,
            hint: hint,
            traits: AppAccessibility.Traits.button
        ))
    }
}

// MARK: - Accessibility Text
struct AccessibilityText: View {
    let text: String
    let isHeading: Bool
    
    init(_ text: String, isHeading: Bool = false) {
        self.text = text
        self.isHeading = isHeading
    }
    
    var body: some View {
        Text(text)
            .modifier(AccessibilityModifier(
                label: text
            ))
            .modifyIf(isHeading) { view in
                view.accessibilityAddTraits(AppAccessibility.Traits.header)
            }
    }
}

// MARK: - Accessibility Image
struct AccessibilityImage: View {
    let systemName: String
    let label: String
    let decorative: Bool
    
    init(
        systemName: String,
        label: String,
        decorative: Bool = false
    ) {
        self.systemName = systemName
        self.label = label
        self.decorative = decorative
    }
    
    var body: some View {
        Image(systemName: systemName)
            .modifyIf(!decorative) { image in
                image.modifier(AccessibilityModifier(
                    label: label,
                    traits: AppAccessibility.Traits.image
                ))
            }
            .modifyIf(decorative) { image in
                image.accessibilityHidden(true)
            }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.lg) {
        Text("Accessibility Manager Preview")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(spacing: AppSpacing.md) {
            AccessibilityButton("New Chat", hint: "Start a new conversation") {
                print("New chat tapped")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(AppSpacing.CornerRadius.md)
            
            AccessibilityButton("Send Message", hint: "Send your message") {
                print("Send message tapped")
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(AppSpacing.CornerRadius.md)
            
            AccessibilityButton("Voice Mode", hint: "Switch to voice input") {
                print("Voice mode tapped")
            }
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(AppSpacing.CornerRadius.md)
        }
        
        HStack(spacing: AppSpacing.md) {
            AccessibilityImage(systemName: "mic.fill", label: "Microphone")
                .foregroundColor(.blue)
            
            AccessibilityImage(systemName: "paperplane.fill", label: "Send")
                .foregroundColor(.green)
            
            AccessibilityImage(systemName: "plus.circle", label: "Add")
                .foregroundColor(.orange)
        }
        .font(.title)
        
        AccessibilityText("This is a heading", isHeading: true)
            .font(.title2)
            .fontWeight(.semibold)
        
        AccessibilityText("This is regular text")
            .font(.body)
    }
    .padding()
    .background(Color(.systemBackground))
}
