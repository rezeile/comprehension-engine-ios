## Chat input stacked-controls plan: place all text above mic/send for full-width lines

### Goal

- Change the input so that all text always spans the full textbox width, with the mic/send controls sitting in their own row below the text inside the same capsule. No wrap-around on the last line. Keep existing UX polish and avoid regressions (Dynamic Type, max-height scrolling, accessibility, RTL, haptics).

### Current behavior (context)

- The input uses a `UITextView` and an exclusion path so only the last line floats above the trailing mic/send cluster (Claude-style). This is working but the debug overlay reveals a moving “collision box,” and the last line can visually step upward.

### Proposed behavior

- Switch to a stacked layout inside the capsule: the `UITextView` occupies the top area at full width; the controls row (mic + send) is placed below it, right-aligned. The input height expands to accommodate both the text and the controls row up to a max height, after which the text view scrolls internally.

### High-level design

- Capsule container → `VStack(spacing: controlsSpacing)`
  - Row 1: `GrowingTextView` (full width; no exclusion path; internal padding unchanged)
  - Row 2: Controls `HStack` (content to the trailing edge; fixed button sizes)
- Overall capsule height: `textHeight + verticalTextPadding*2 + controlsRowHeight + controlsBottomPadding + controlsSpacing` (numbers below).

### Layout math

- Keep the existing text paddings from `ChatInputView`:
  - `textViewHorizontalPadding = AppSpacing.Component.inputPadding - 12`
  - `textViewVerticalPadding = AppSpacing.Component.inputPadding - 6`
- Controls paddings (inside capsule):
  - trailing: 6 (unchanged)
  - bottom: 4 (unchanged)
  - inter-control spacing: 4 (unchanged)
- Spacing between the text and controls rows: `controlsSpacing = 4` (new constant; tunable 0–6)
- Capsule height formula:
  - `capsuleHeight = inputHeight + (textViewVerticalPadding * 2) + controlsRowHeight + 4 /* bottom */ + controlsSpacing`
- Max height logic stays the same: `inputHeight` clamps between `minHeight` and `maxHeight`. When `sizeThatFits` exceeds `maxHeight`, `UITextView` turns on internal scrolling.

### Implementation plan (small, safe edits)

Files to touch:

1) `ComprehensionEngine/Views/ChatInputView.swift`
   - Introduce a layout mode toggle (scoped constant for now):
     - `enum InputLayoutMode { case wrapAboveControls, stackedControls }`
     - Set local `let layoutMode: InputLayoutMode = .stackedControls` (for rollout; can be switched back easily).
   - When `.stackedControls`:
     - Replace the current `ZStack` overlay approach with a `VStack(spacing: controlsSpacing)` inside the same capsule background/overlay.
     - Top: `GrowingTextView` configured with `trailingAccessorySize: .zero` to disable the exclusion path logic. Keep `textViewHorizontalPadding` and vertical padding as-is.
     - Bottom: Reuse the existing mic/send `HStack(spacing: 4)` aligned trailing. Keep button frames (36×36), labels, disabled opacity, etc.
     - Measure the controls row height via `GeometryReader`/`PreferenceKey` into `controlsRowHeight` and add it to the final capsule height:
       - `.frame(height: inputHeight + (textViewVerticalPadding * 2) + controlsRowHeight + 4 /* bottom */ + controlsSpacing)`
     - Continue to subtract the trailing/bottom paddings from the measured controls size if needed (consistent with current measurement fix).
   - When `.wrapAboveControls` (legacy fallback):
     - Keep current layout and continue passing `trailingAccessorySize` (corrected and de-padded) to `GrowingTextView`.

2) `ComprehensionEngine/Views/Shared/GrowingTextView.swift`
   - No structural changes required for stacked mode. Passing `trailingAccessorySize = .zero` already clears exclusion paths.
   - Keep `lineFragmentPadding = 0`, placeholder alignment, Dynamic Type tracking, max-height behavior, and the debounced on-layout recomputation (safe even if exclusion is off).
   - Optional: guard DEBUG overlay rendering with `if trailingAccessorySize != .zero` so it remains silent in stacked mode.

### Accessibility

- Reading order: text view first, then mic, then send (unchanged). Ensure `.accessibilityLabel` strings remain intact.
- Hit targets are the same (36×36). No overlap with the text view since controls are separate.
- Dynamic Type: buttons keep their size; if needed, we can scale the button frames slightly for XXL+ in a follow-up.

### RTL

- With stacked layout, no horizontal exclusion logic is needed. The controls `HStack` will automatically mirror to the leading side in RTL; if we must keep them visually on the trailing side for RTL too, set explicit alignment: `.frame(maxWidth: .infinity, alignment: .trailing)`.

### Performance

- Removing the live exclusion-rect updates for stacked mode reduces layout churn.
- Existing debounce in `PlaceholderTextView.layoutSubviews()` prevents feedback loops.

### Testing checklist

- Long text at various lengths: all lines are full width; controls appear as a fixed row below.
- Delete text: capsule height shrinks smoothly; no jumping.
- Max height reached: internal scrolling kicks in; controls remain visible and stable.
- Dynamic Type L–XXL: no clipping; placeholder aligns; controls row remains visible and accessible.
- Rotation + RTL: layout mirrors as expected; controls row stays aligned trailing.
- VoiceOver: traversal order is logical; controls are reachable with correct labels.
- Regression: keyboard show/hide, return-to-send, haptics on send, and disabled send opacity remain correct.

### Rollout/rollback

- Rollout by flipping `layoutMode` to `.stackedControls` locally in `ChatInputView`.
- Rollback by switching back to `.wrapAboveControls` with zero code deletion.

### Notes

- This plan is intentionally low-risk and reversible. It does not delete the wrap-above-controls path; it adds a simpler stacked layout and toggles between the two.





