### Follow-up: Fix oversized input and keyboard pinning

This document captures the investigation into the oversized input shown in the screenshots and proposes targeted edits that align with modern SwiftUI patterns (iOS 17/18).

## Observed issues

- Input capsule renders extremely tall even when the text is empty.
- When the keyboard appears, the input area is not abutting the keyboard; it sits too high on the screen.

## Root causes

1) Unconstrained background shape in `ChatInputView`:
   - The `RoundedRectangle` placed as a child inside a `ZStack` expands to the maximum vertical space offered by the parent layout, causing the container to grow far beyond the `GrowingTextView` height.
   - Only the `GrowingTextView` had a fixed height; the surrounding `ZStack` (with the shape) did not. In SwiftUI, a shape without an explicit frame will expand to fill the proposed size.

2) Double-adjustment for keyboard:
   - The screen used `.keyboardAware()` on the outer container while `ChatInputView` also used `.ignoresSafeArea(.keyboard, edges: .bottom)`. The combination introduces excess bottom space, pushing the input away from the keyboard.

3) Initial measurement edge case (minor):
   - `GrowingTextView` measures with `uiView.bounds.width`. On the first layout pass this can be zero, and our fallback width may be imperfect. This doesn’t create the extreme height by itself, but we can harden it to avoid transient jumps.

## Plan of record (edits)

### A) Constrain the input capsule to the content height

- Wrap the capsule container in a fixed-height frame derived from the measured text height plus vertical paddings.
- Move the `RoundedRectangle` from being a `ZStack` child to being a `.background` (and `.overlay` for the border) on a container that already has a concrete height. This prevents the shape from expanding the layout.
- Keep the send button as an overlay so it doesn’t affect intrinsic height.

Proposed structure inside `ChatInputView` (conceptual):

```swift
// Inside HStack
let vPad: CGFloat = AppSpacing.Component.inputPadding - 6

ZStack(alignment: .bottomTrailing) {
    // Placeholder
    if trimmedText.isEmpty { placeholderView }

    GrowingTextView(
        text: $text,
        height: $inputHeight,
        minHeight: 40,
        maxHeight: 136,
        onReturn: sendIfPossible
    )
    .frame(height: inputHeight)
    .padding(.horizontal, AppSpacing.Component.inputPadding - 2)
    .padding(.vertical, vPad)

    sendButton
}
.frame(height: inputHeight + vPad * 2)
.background(
    RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.pill)
        .fill(AppColors.backgroundSecondary)
)
.overlay(
    RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.pill)
        .stroke(AppColors.inputBorder, lineWidth: 1)
)
```

Notes:
- The critical change is applying `.frame(height: inputHeight + verticalPadding*2)` to the container that owns the background shape. This pins the visual capsule height to the text content, eliminating the runaway expansion.

### B) Adopt `safeAreaInset` for keyboard pinning and remove double bottom-padding

- In `ChatView`, remove `.keyboardAware()` from the outer `VStack`.
- Place the input via `safeAreaInset(edge: .bottom) { ChatInputView(...) }` so it naturally abuts the keyboard (modern SwiftUI approach), and keep `.scrollDismissesKeyboard(.immediately)` on the scroll view.
- Keep the tap/drag dismissal gesture.

Conceptual changes in `ChatView`:

```swift
VStack(spacing: 0) {
    ScrollViewReader { proxy in
        ScrollView { ... }
            .scrollDismissesKeyboard(.immediately)
            .onReceive(keyboardWillShow) { scrollToBottom(proxy) }
            .keyboardDismissal { dismissKeyboard() }
    }
}
// Remove .keyboardAware()
.safeAreaInset(edge: .bottom) {
    ChatInputView(
        text: $inputText,
        onSend: sendTextMessage,
        onVoiceMode: { showingVoiceMode = true }
    )
}
```

Notes:
- `safeAreaInset` keeps the input visually pinned to the bottom and automatically cooperates with the software keyboard. We no longer need to add bottom padding equal to keyboard height to the entire screen.

### C) Harden `GrowingTextView`’s initial measurement (optional but recommended)

- Only enable internal scrolling after we have a non-zero width measurement. Until then, clamp height to `minHeight`.
- Keep the right `textContainerInset` so text does not flow under the send button.

Conceptual tweak:

```swift
let width = uiView.bounds.width
if width > 0 {
    let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    // update height and isScrollEnabled from size
} else {
    // First pass: keep height at current (or minHeight) and isScrollEnabled = false
}
```

## Acceptance criteria

- Input starts at a single-line height when empty and grows line by line until `maxHeight`, then scrolls internally.
- Input capsule visually abuts the keyboard when it’s visible, with no extra gap.
- Placeholder and send button remain correctly positioned; text never flows under the button.
- Scrolling still snaps to the latest message on new messages and when the keyboard appears.

## Rollout order

1. Apply edits in `ChatInputView` to constrain container height and move the shape to `.background`/`.overlay`.
2. Switch `ChatView` to `safeAreaInset(edge: .bottom)` and remove `.keyboardAware()` from the outer container.
3. Optional: Harden `GrowingTextView`’s first-pass measurement guard.
4. Build and verify on iPhone simulators (iOS 18.6) and a physical device.

## Notes on backward compatibility

- These changes are limited to the chat screen. `ModernTextEditor` remains unchanged for other screens to avoid regressions.
- Using `safeAreaInset` is available on iOS 15+, and aligns with modern SwiftUI keyboard handling guidelines.


