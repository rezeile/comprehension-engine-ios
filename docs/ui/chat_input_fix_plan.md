## Fix chat input: align placeholder with caret, move mic into textbox (left of Send), keep auto-grow

### Context (assets attached)
- **Screenshot A**: current app (placeholder "Message…" is not aligned with the blinking caret)
- **Screenshot B**: Claude iOS input (caret‑aligned placeholder, mic inside the input, to the left of Send)
- **Screenshot C**: ChatGPT iOS input (same behavior)

### Goal
Update the SwiftUI chat input so that:
- **Placeholder** text aligns exactly with the caret/baseline.
- **Microphone** button lives inside the input field, to the left of **Send**.
- **Auto‑growing** multiline text box keeps expanding/shrinking on line wrap exactly as it does now.
- **No regressions** anywhere else in the app.

### What to do (plan + execution)

#### Identify current component(s)
- Search the codebase for the chat input view (likely names like `MessageInputView`, `ChatInputBar`, `Composer`, `ChatToolbar`, etc.) and any `TextEditor`/`UITextViewRepresentable` used for auto‑sizing.
- List the files and symbols that will be changed.

#### Baseline capture
- Open a quick preview/simulator and record the current behavior:
  - min height / max height
  - line‑wrap thresholds
  - internal/external padding and insets
- This baseline must be preserved after the change.

#### Placeholder/caret alignment fix
- If using SwiftUI `TextEditor`:
  - Replace any ad‑hoc placeholder implementation with a `ZStack(alignment: .topLeading)` overlay whose padding matches the text container insets used by the editor.
  - Typical values that align with the caret are approximately `.padding(.top, 8)` and `.padding(.leading, 4)` — but read the current code and match whatever insets are actually applied (including `.textEditorStyle`, `.lineSpacing`, and any custom `UITextView` insets if wrapping UIKit).
- If using a `UITextViewRepresentable` for auto‑sizing:
  - Set the placeholder label’s constraints/insets to the `textContainerInset` and `textContainer.lineFragmentPadding` so the placeholder baseline equals the caret baseline.
- Ensure placeholder hides/shows based on `text.isEmpty` and respects Dynamic Type and right‑to‑left (RTL).

#### Embed mic inside the input field
- Move the mic button into the same rounded input container as the text (trailing side), before the Send button.
- Structure:
  - `HStack { AutoSizingEditor ; Spacer(min: 8) ; MicButton ; SendButton }` inside the rounded background.
  - Maintain hit targets (≥ 44 pt).
- Use the app’s existing mic handler/action; don’t introduce new side effects.

#### Preserve auto‑grow behavior
- Keep the existing auto‑sizing mechanism (`PreferenceKey`/`GeometryReader` or `UITextView` intrinsic size).
- Maintain current `minHeight`, `maxHeight` (clip and make scrollable only after max).
- Verify that adding the trailing buttons does not change line‑wrap thresholds or cause layout jumps. If text width shrinks, adjust internal padding so line breaks match the current feel as closely as possible.

#### Styling
- Match the current typography, corner radius, border, and background color.
- Keep the Send button visually anchored to the trailing edge; mic sits immediately to its left, inside the input.
- Ensure the placeholder and typed text use the same baseline and vertical centering.

#### Accessibility & keyboard
- VoiceOver labels for Mic ("Start voice input") and Send.
- Support keyboard dismissal as it works today; do not regress.

### Testing checklist (build & run)
- **Placeholder baseline == caret baseline** on first character.
- **Add/remove lines**: textbox grows/shrinks smoothly; no layout jump.
- **Long text past maxHeight** becomes vertically scrollable inside the field.
- **Mic and Send** are both inside the rounded field; mic is left of Send; tap areas ≥ 44 pt.
- **RTL** languages: placeholder alignment and button order mirror correctly.
- **Dynamic Type**: no clipping; min/max heights scale appropriately.
- **No changes** to other screens/components.

### Documentation output (post‑implementation)
Create `docs/ui/chat_input_refactor.md` with:
- Summary of current implementation (files, key structs/classes).
- Exactly what changed (file list + brief rationale).
- Insets/padding values used to align placeholder to caret.
- Any constraints or `textContainerInset` settings applied.
- Screenshots/GIFs before vs after.
- Known limitations and future improvements.

### Acceptance criteria (must all pass)
- ✅ Placeholder visually aligned with caret baseline (compare to Claude/ChatGPT examples).
- ✅ Mic button lives inside the input field, to the left of Send.
- ✅ Auto‑grow behavior on line wrap unchanged (min/max heights preserved).
- ✅ No regressions or crashes; existing keyboard dismissal behaviors intact.
- ✅ `docs/ui/chat_input_refactor.md` added with the items above.

### Constraints
- Do not refactor unrelated modules.
- Keep public APIs and view model interfaces stable.
- No new third‑party dependencies.
- Keep diff small and localized.

### Starting pattern (only if consistent with current code)
- SwiftUI `TextEditor` with overlay placeholder:

```swift
ZStack(alignment: .topLeading) {
    TextEditor(text: $text)
        .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
    if text.isEmpty {
        Text("Message…")
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .padding(.leading, 4)
    }
}
```

- Wrap in `HStack { editor ; MicButton ; SendButton }` inside a rounded rectangle background.
- For a UIKit wrapper: match `placeholderLabel` insets to `textView.textContainerInset` and `lineFragmentPadding`.

Note: This file captures the plan only. Implementation will be done in a subsequent step.


