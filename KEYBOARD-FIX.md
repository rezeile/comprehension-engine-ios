# Prompt for Cursor (iOS chat input like ChatGPT/Claude)

You are editing an iOS chat app. Improve the **composer/input bar** so it matches the UX of ChatGPT/Claude.

## Goals (behavioral spec)

1. **Growing input**

   * Starts as a **single-line** height (no large empty area).
   * **Expands and shrinks** with text wrapping: grows when a new line is reached, shrinks when lines are deleted.
   * Set `minHeight ≈ 36–40pt`, `maxHeight ≈ 120–140pt` (\~4–5 lines). After max height, the text view **scrolls internally**.
   * Shows a **placeholder** when empty.

2. **Full-width bar with embedded Send**

   * Input bar spans the screen width and respects safe areas.
   * **Send arrow/button** is embedded at the **lower-right inside** the text field capsule, not as a separate trailing bar item.
   * Button is **disabled** when trimmed text is empty; tapping **sends** (calls existing send handler), **clears** the field, and **resets height**.

3. **Keyboard handling**

   * The messages list isn’t obscured by the keyboard (use safe area insets or keyboard avoidance).
   * Support **dismiss on tap outside** the input and **drag-down** to dismiss.
   * When the keyboard appears, scroll the messages list to the last message.

4. **Look & feel**

   * Rounded capsule background for the input, subtle border in light/dark mode, comfortable padding.
   * Haptics on send.
   * Works with Dynamic Type, VoiceOver, and RTL.

## Implementation constraints

* **Prefer SwiftUI** if the project is SwiftUI; otherwise provide a UIKit implementation.
* In SwiftUI, wrap `UITextView` inside `UIViewRepresentable` to get intrinsic height.
* Keep the input component self-contained (`ChatInputView.swift`) and easy to reuse.
* No third-party deps.

## Deliverables

1. `ChatInputView.swift` – reusable SwiftUI view (or `GrowingTextView.swift` + `ChatInputBar.swift` for UIKit) implementing the above.
2. Minimal integration code showing how to place it above a `ScrollView`/`List` of messages that auto-scrolls on send.
3. Unit/UI test notes or a small checklist in comments.

## SwiftUI reference implementation (use/adjust as needed)

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
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
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

struct ChatInputView: View {
    @Binding var text: String
    var onSend: (String) -> Void

    @State private var height: CGFloat = 40
    private let minH: CGFloat = 40
    private let maxH: CGFloat = 136

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                // Background capsule
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.separator), lineWidth: 0.5))

                // Placeholder
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Message…")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Growing text view
                GrowingTextView(text: $text, height: $height, minHeight: minH, maxHeight: maxH, onReturn: sendIfPossible)
                    .frame(height: height)
                    .padding(.horizontal, 10).padding(.vertical, 6)

                // Embedded send
                Button(action: sendIfPossible) {
                    Image(systemName: "paperplane.fill")
                        .imageScale(.medium)
                        .padding(10)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                .padding(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func sendIfPossible() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend(trimmed)
        text = ""
        height = minH
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
```

### Integration example

```swift
struct ChatScreen: View {
    @State private var messages: [String] = []
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages.indices, id: \.self) { i in
                            Text(messages[i]).padding(12)
                                .background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 12))
                                .id(i)
                        }
                    }.padding(.horizontal).padding(.top)
                }
                .scrollDismissesKeyboard(.immediately) // drag-down to dismiss
                .onChange(of: messages.count) { _, _ in
                    DispatchQueue.main.async { proxy.scrollTo(messages.indices.last, anchor: .bottom) }
                }
                .onTapGesture { UIApplication.shared.endEditing() } // tap outside to dismiss
            }

            ChatInputView(text: $draft) { text in
                messages.append(text)
            }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) } // ensures clean inset under keyboard
    }
}

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
```

## UIKit reference (if project is UIKit)

* Use a `UITextView` inside a container view with constraints:

  * Pin leading/trailing to container with padding, set min height via `>=` constraint, keep a height constraint you update from `textViewDidChange`.
  * Use `layoutManager.usedRect(for:)` or `sizeThatFits` to compute height; clamp to `maxHeight`; set `textView.isScrollEnabled = height == maxHeight`.
  * Add a trailing `UIButton` inside the same container (overlapping bottom-right).
  * Add tap gesture to the table/collection view and a `UIScrollView.keyboardDismissMode = .interactive` for drag-down.

## Acceptance checklist

* [ ] Composer starts single-line; no large empty box.
* [ ] Grows/shrinks exactly with content; scrolls internally after \~5 lines.
* [ ] Send button embedded in the field; disabled when empty.
* [ ] Keyboard doesn’t cover content; list scrolls to bottom on send.
* [ ] Tap background OR drag down dismisses keyboard.
* [ ] Works in light/dark, RTL, and with Dynamic Type.

Apply this, modify file names/structures to match the project, and keep all changes in a focused PR.
