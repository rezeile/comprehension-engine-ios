### KEYBOARD-FIX Adaptation Plan for ComprehensionEngine

This document adapts the guidance in `KEYBOARD-FIX.md` to the current SwiftUI codebase, preserving the existing architecture and naming while upgrading the chat input experience.

## Current Architecture Analysis

- **Chat container and list**: `ChatView` owns the message list and input.

```3:18:ComprehensionEngine/Views/ChatView.swift
struct ChatView: View {
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var audioManager: AudioManager
    @State private var inputText = ""
    ...
    VStack(spacing: 0) {
        // Chat messages list
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatManager.messages) { message in
                        ModernChatMessageView(message: message)
                            .id(message.id)
                    }
                    if chatManager.isLoading { TypingIndicator() }
                }
                .padding(...)
            }
            .onChange(of: chatManager.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
        // Input area
        ChatInputView(
            text: $inputText,
            onSend: sendTextMessage,
            onVoiceMode: { showingVoiceMode = true }
        )
    }
}
```

- **Input component**: `ChatInputView` composes a voice button, `ModernTextEditor`, and a trailing send button.

```1:20:ComprehensionEngine/Views/ChatInputView.swift
struct ChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    let onVoiceMode: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: AppSpacing.Component.inputSpacing) {
                ModernIconButton(icon: "mic.fill", style: .secondary, size: .base) { onVoiceMode() }
                ModernTextEditor(placeholder: "Message", text: $text, minHeight: 44, maxHeight: 120, ...)
                ModernIconButton(icon: "paperplane.fill", style: .primary, size: .base) { onSend() }
            }
            .padding(...)
            .background(AppColors.background)
            .shadow(AppSpacing.Shadow.small)
        }
    }
}
```

- **Text editor**: `ModernTextEditor` wraps `TextEditor` with placeholder and fixed `frame(minHeight:maxHeight:)`. It does not dynamically grow by intrinsic height nor scroll internally past max height.

```115:172:ComprehensionEngine/Views/Shared/ModernTextField.swift
struct ModernTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    ...
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty { Text(placeholder) ... }
            TextEditor(text: $text)
                .focused($isFocused)
                .padding(...)
        }
        .frame(minHeight: minHeight, maxHeight: maxHeight)
        .background(...)
        .overlay(...)
        .cornerRadius(...)
        .shadow(...)
    }
}
```

- **Keyboard utilities**: `KeyboardManager` exists with `.keyboardAware()` and `.keyboardDismissal(...)` modifiers, but they are not applied in `ChatView`.

```1:18:ComprehensionEngine/Utilities/KeyboardManager.swift
class KeyboardManager: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible = false
    @Published var keyboardAnimationDuration: Double = 0.25
}
```

## Relevant Instructions from KEYBOARD-FIX.md

- **Growing input**: Use a `UITextView` via `UIViewRepresentable` to compute intrinsic height; clamp between `minHeight` and `maxHeight`; enable internal scrolling after max.
- **Embedded send button in a full-width capsule**: Send action disabled when trimmed text is empty; sending clears text and resets height.
- **Keyboard handling**: Avoid content being obscured; support tap outside and drag-down to dismiss; scroll list to bottom on keyboard appear and on send.
- **Look & feel**: Rounded capsule, subtle border, Dynamic Type, haptics on send.

## File-Specific Changes

### 1) Add reusable growing text view (new)

Create `ComprehensionEngine/Views/Shared/GrowingTextView.swift`.

```swift
import SwiftUI
import UIKit

struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let onReturn: (() -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 36) // extra right padding for send button
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        let size = uiView.sizeThatFits(CGSize(width: uiView.bounds.width, height: .greatestFiniteMagnitude))
        var newHeight = max(minHeight, size.height)
        newHeight = min(maxHeight, newHeight)
        if height != newHeight { DispatchQueue.main.async { self.height = newHeight } }
        uiView.isScrollEnabled = size.height > maxHeight
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: GrowingTextView
        init(_ parent: GrowingTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText string: String) -> Bool {
            if string == "\n" && textView.textInputMode?.primaryLanguage != "emoji" {
                parent.onReturn?()
                return false
            }
            return true
        }
    }
}
```

Notes:
- The right inset is increased to avoid text clipping under the embedded send button.

### 2) Update `ChatInputView` to use the growing view and embed the send button

Edit `ComprehensionEngine/Views/ChatInputView.swift`:

- Replace the `ModernTextEditor` and trailing send button with a single capsule that contains placeholder, the `GrowingTextView`, and an embedded send button aligned bottom-trailing.
- Maintain the leading mic button and existing spacing tokens.
- Reset height on send and trigger a light haptic.

Proposed body for the `HStack` inside `VStack`:

```swift
HStack(spacing: AppSpacing.Component.inputSpacing) {
    // Voice
    ModernIconButton(icon: "mic.fill", style: .secondary, size: .base) { onVoiceMode() }

    // Capsule container with growing input + embedded send
    ZStack(alignment: .bottomTrailing) {
        // Capsule background + subtle border
        RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.pill)
            .fill(AppColors.backgroundSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.pill)
                    .stroke(AppColors.inputBorder, lineWidth: 1)
            )

        // Placeholder
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("Message…")
                .foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, AppSpacing.Component.inputPadding)
                .padding(.vertical, AppSpacing.Component.inputPadding - 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        // Growing text view
        GrowingTextView(
            text: $text,
            height: $inputHeight,
            minHeight: 40,
            maxHeight: 136,
            onReturn: sendIfPossible
        )
        .frame(height: inputHeight)
        .padding(.horizontal, AppSpacing.Component.inputPadding - 2)
        .padding(.vertical, AppSpacing.Component.inputPadding - 6)

        // Embedded send button
        Button(action: sendIfPossible) {
            Image(systemName: "paperplane.fill")
                .imageScale(.medium)
                .foregroundColor(AppColors.textPrimary)
                .padding(10)
        }
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        .padding(6)
    }
}
.padding(.horizontal, AppSpacing.Layout.screenMarginSmall)
.padding(.vertical, AppSpacing.md)
.background(AppColors.background)
.shadow(AppSpacing.Shadow.small)
.ignoresSafeArea(.keyboard, edges: .bottom)
```

Supporting state and helper in `ChatInputView`:

```swift
@State private var inputHeight: CGFloat = 40

private func sendIfPossible() {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    onSend()
    text = ""
    inputHeight = 40
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
```

### 3) Enhance keyboard handling and dismissal in `ChatView`

Edit `ComprehensionEngine/Views/ChatView.swift`:

- Add drag-down to dismiss to the `ScrollView` and a tap-to-dismiss gesture using the existing modifier.
- Ensure we scroll to the bottom when the keyboard appears.
- Apply `.keyboardAware()` to the outer container to avoid content being obscured.

Suggested changes:

```swift
VStack(spacing: 0) {
    ScrollViewReader { proxy in
        ScrollView {
            ...
        }
        .scrollDismissesKeyboard(.immediately)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            DispatchQueue.main.async {
                scrollToBottom(proxy: proxy)
            }
        }
        .keyboardDismissal {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    ChatInputView(...)
}
.keyboardAware()
```

No changes needed to `KeyboardManager.swift` beyond usage above.

## Implementation Priority

1. **Growing input & embedded send (critical)**: Add `GrowingTextView` and update `ChatInputView` to use it with the capsule and embedded send.
2. **Keyboard behavior (high)**: Apply `.scrollDismissesKeyboard`, `.keyboardDismissal`, and `.keyboardAware()`, and scroll to bottom on keyboard show.
3. **Styling polish (medium)**: Fine-tune paddings, colors, and border widths to match `AppColors`/`AppSpacing`.
4. **Haptics & Accessibility (medium)**: Confirm Dynamic Type behavior and VoiceOver labels; keep the light haptic on send.

## Potential Issues / Considerations

- **Intrinsic sizing with `UITextView`**: The initial `sizeThatFits` needs a valid width. Using `.frame(height:)` plus standard SwiftUI layout will provide width after first layout pass; height updates occur via `DispatchQueue.main.async` to avoid feedback loops.
- **Return key behavior**: `onReturn` will send on Return for text keyboards. For emoji keyboards, Return is ignored (matches reference).
- **Text under send button**: The increased right `textContainerInset.right` (36) keeps text from flowing under the button.
- **Focus management**: If you rely on `@FocusState` elsewhere, you can keep it for other inputs; `GrowingTextView` manages its own focus via `UITextView`.
- **The existing `ModernTextEditor`** remains for other screens; we are not modifying it to avoid regressions.
- **Safe area/keyboard interactions**: `.keyboardAware()` adds bottom padding for the keyboard; `.ignoresSafeArea(.keyboard, edges: .bottom)` on the input ensures clean visual pinning to the keyboard.

## Minimal Edit Checklist

- Add `GrowingTextView.swift` under `Views/Shared`.
- Update `ChatInputView.swift` to embed send and use the new growing view.
- Update `ChatView.swift` for keyboard dismissal and auto-scroll behavior.
- Build and verify:
  - Input starts single-line; grows to ~4–5 lines then scrolls internally.
  - Send disabled when input is empty; sends, clears, and resets height.
  - Tap background or drag down dismisses the keyboard.
  - List scrolls to bottom on new messages and when keyboard appears.


