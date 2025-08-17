## Chat input follow‑up plan: precise placeholder baseline + no wrap overlap

This plan addresses the two remaining issues after the first pass:

- Placeholder baseline is not perfectly aligned with the caret
- Wrapped lines can run underneath the mic/send buttons

Everything else (auto‑grow behavior, styling, button placement) remains unchanged.

### Diagnosis (based on current code)

- `GrowingTextView` uses a UIKit `UITextView` for auto‑sizing with `textContainerInset = {top: 8, left: 6, bottom: 8, right: 6}`. The placeholder is rendered in SwiftUI as an overlay `Text` above the text view in `ChatInputView`.
  - Because the placeholder is not inside the `UITextView`, it does not automatically inherit the exact `textContainerInset` and `lineFragmentPadding` used by the caret, leading to a small but visible misalignment.
- Mic and Send live inside the same capsule, overlaid in the trailing corner. The text view’s `right` inset is a fixed `6`, so when content wraps, glyphs can continue under the trailing buttons.

### Goals

1) Placeholder’s baseline exactly matches the caret baseline.
2) Wrapped lines never render under the trailing accessory buttons.
3) Preserve existing min/max height logic and smooth auto‑grow behavior.
4) No visual regressions to capsule styling or button placement.

### Planned changes (surgical, localized)

#### 1) Move placeholder into `GrowingTextView` (UIKit level)

- Add parameters to `GrowingTextView`:
  - `placeholder: String`
  - `placeholderColor: UIColor` (default to a system tertiary label color mapped from `AppColors.textTertiary`)
  - `trailingAccessoryWidth: CGFloat` (see step 2)
- Inside `makeUIView`:
  - Create `UILabel` (`placeholderLabel`) and add it as a subview of the `UITextView`.
  - Constrain `placeholderLabel` to match the caret’s baseline by using the same metrics:
    - leading = `textContainerInset.left + textContainer.lineFragmentPadding`
    - top = `textContainerInset.top`
    - width ≤ `bounds.width - (leading + textContainerInset.right)`
  - Set `placeholderLabel.font = uiTextView.font` to match the caret font exactly.
- Inside `updateUIView`:
  - Toggle `placeholderLabel.isHidden = !text.isEmpty`.
  - Update constraints if `textContainerInset` changes (due to step 2).

Result: placeholder baseline and caret are guaranteed to align because both are rendered within the same `UITextView` with identical insets and font.

#### 2) Prevent text overlap under mic/send by increasing trailing inset dynamically

- In `ChatInputView`, measure the combined width of the trailing accessories (mic + spacing + send + internal trailing padding) using a `PreferenceKey` on the trailing `HStack`:
  - Define `AccessorySizePreferenceKey: PreferenceKey` storing `CGFloat`.
  - Attach `.background(GeometryReader { Color.clear.preference(key: ..., value: geo.size.width) })` to the trailing controls.
  - Use `.onPreferenceChange` to store `accessoryWidth` in a local `@State`.
- Pass `trailingAccessoryWidth = accessoryWidth + 6` into `GrowingTextView` and, inside `updateUIView`, set:
  - `textView.textContainerInset.right = 6 + trailingAccessoryWidth`
  - Keep `left = 6, top = 8, bottom = 8` as today.
- RTL support: if `effectiveUserInterfaceLayoutDirection == .rightToLeft`, swap leading/trailing logic by adjusting `textContainerInset.left` instead of `right`, and mirror placeholder constraints.

Result: the text layout area shrinks to avoid the mic/send region, so wrapped lines never flow underneath the buttons.

#### 3) Keep layout structure and styling stable

- Continue to render mic and send inside the capsule on the trailing side as today.
- Retain current paddings, corner radius, border, colors, and shadows.
- Keep auto‑grow unchanged: intrinsic height computation and scroll‑after‑max logic remain in `GrowingTextView`.

### Files to edit

- `ComprehensionEngine/Views/Shared/GrowingTextView.swift`
  - Add placeholder support (`UILabel`), dynamic trailing inset, and RTL handling.
  - Expose `placeholder`, `placeholderColor`, and `trailingAccessoryWidth` parameters.
- `ComprehensionEngine/Views/ChatInputView.swift`
  - Remove SwiftUI overlay placeholder.
  - Measure trailing accessory width via `PreferenceKey` and pass to `GrowingTextView`.
  - Keep mic/send placement and accessibility labels.

### Acceptance criteria

- Placeholder and caret baselines are visually identical at rest and when typing the first character.
- With long text, wrapped lines never render beneath mic/send at any width or Dynamic Type size.
- Auto‑grow min/max heights and the internal scrolling after max remain unchanged.
- No regressions to styling or keyboard behavior; send still disables when input is empty.
- RTL and Dynamic Type verified; placeholder alignment and insets mirror correctly in RTL.

### Test checklist

- Launch simulator and verify:
  - Empty state: placeholder baseline equals caret baseline.
  - Type to first character: placeholder hides, caret position unchanged; no jump.
  - Paste long text: grows to max, then scrolls internally; no overlap with trailing controls.
  - Rotate device and change Dynamic Type sizes: no clipping; alignment holds.
  - Toggle RTL in Scheme Application Language: layout and insets mirror properly.

### Rollback plan

- If any visual regression is detected, revert to the prior `ChatInputView.swift` placeholder overlay and set `textContainerInset.right` back to `6`. Changes are localized to the two files listed above.

### Notes

- No new dependencies.
- Public APIs remain stable; `GrowingTextView` gains optional parameters with defaults so existing usages (if any elsewhere) are unaffected.


