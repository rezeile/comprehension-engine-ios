## Chat input overflow fix: collision-aware wrapping (Claude-style)

### Final approach

- Implemented a UIKit-based solution using `UITextView`'s `textContainer.exclusionPaths` to reserve a rounded rectangle at the bottom-trailing of the text container. This prevents the active (last) line from flowing under the mic/send cluster while allowing earlier lines to use full width.
- Placeholder is rendered inside the same `UITextView` to match caret metrics (baseline alignment preserved).
- Auto-grow behavior and styling remain unchanged. Scrolling activates only after reaching `maxHeight`.

### Where the exclusion rect is computed

- File: `ComprehensionEngine/Views/Shared/GrowingTextView.swift`
- Function: `updateExclusionPath(for:)`
- Inputs:
  - `trailingAccessorySize: CGSize` measured at runtime in `ChatInputView` via a `PreferenceKey`
  - `collisionGap: CGFloat` to keep a small gap between the last line and controls
- Logic:
  - Uses the `UITextView`'s `textContainerInset` and current `bounds` to compute the text container coordinates.
  - Places a rounded exclusion rect anchored to bottom-trailing in LTR; mirrored to bottom-leading in RTL.
  - Updates `textContainer.exclusionPaths` on each `updateUIView` so changes in size, orientation, Dynamic Type, and content are reflected.

### Constants used

- Insets: `top=8, bottom=8, left=6, right=6`
- Gap: `collisionGap = 6` (tunable)
- Exclusion corner radius: `8`

### SwiftUI integration

- File: `ComprehensionEngine/Views/ChatInputView.swift`
- Measures the trailing mic/send cluster size with `AccessorySizePreferenceKey`:
  - Attaches a `GeometryReader` as `.background` to the mic/send `HStack`.
  - Passes `trailingAccessorySize` and `collisionGap` into `GrowingTextView`.
- The previous overlay placeholder was removed; `GrowingTextView` now owns the placeholder.

### Behavior notes

- Earlier lines: full bubble width
- Last line: wraps above exclusion rect with ~6pt gap
- On delete: exclusion remains but only affects the active line; no width penalty to earlier lines
- Max height: internal scrolling enabled; exclusion continues to prevent overlap
- RTL: exclusion rect mirrors to the leading side
- Accessibility: existing labels preserved for mic (“Start voice input”) and send; no changes to focus order

### Screenshots

- Please capture before/after screenshots in simulator:
  - Empty state baseline alignment
  - Long input showing last line wrapping above mic/send
  - Max height with internal scroll
  - RTL layout

### Testing checklist

- Typing long text: earlier lines full width; final line wraps above controls with visible gap
- Deleting text: no layout jumps; width returns to full appropriately
- Rotate device; change Dynamic Type: no clipping or misalignment
- Max height reached: scrolls; exclusion still respected
- RTL verified: mirrored correctly


