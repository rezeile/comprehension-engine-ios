## Chat input overflow follow‑up: why exclusion path still leaves a big right gap, and how to fix it

### Symptom

- Text still appears shifted left across all lines with a large empty region on the right; the last line does not consistently float above the mic/send cluster.
- Goal remains: earlier lines are full width; only the active (last) line wraps above the trailing controls with a small gap (Claude‑style).

### Likely causes (hypotheses)

1) Misaligned coordinate space for exclusion path
   - Our exclusion rect is computed from `uiView.bounds` minus `textContainerInset`. However, UIKit’s exclusion paths are in the text container’s coordinate space. Using `bounds` can be correct, but subtle differences (e.g., content size vs container size, transforms) can place the rect too far left or with the wrong width.

2) `lineFragmentPadding` not zero
   - We didn’t set `textContainer.lineFragmentPadding = 0`. Default padding (~5pt) adds side margins that, combined with the exclusion rect, make the right gap appear larger.

3) Over‑reserving horizontally by not accounting for SwiftUI paddings
   - The mic/send cluster is padded `.trailing = 6`, while the `UITextView` is padded `.horizontal = 4` inside the capsule. We currently reserve the full accessory width, but the overlap inside the text container is `accessoryWidth - (accessoryTrailingPadding - textViewTrailingPadding)`. Failing to subtract that delta over‑reserves width across the last line and can look like a persistent right gap.

4) Vertical placement tied to container height instead of used text height
   - We anchor the exclusion rect to the container’s bottom. With small content, the rect may intersect multiple line fragments (not just the last one), causing earlier lines to wrap left prematurely. Anchoring to `usedRect(for:)` ensures the rect only pushes the active line up.

5) Measured accessory size too big
   - The `GeometryReader` may include invisible padding around the HStack (e.g., bottom/trailing padding). Using that size directly can overshoot the collision rect.

6) RTL mirroring edge cases
   - If layout direction flips and we don’t recompute the horizontal delta between text view padding and accessory padding, the rect may sit on the wrong side or reserve excess width.

### Investigation plan

1) Add debug overlay for the exclusion rect (DEBUG only)
   - In `PlaceholderTextView`, draw a semi‑transparent layer mirroring the computed exclusion rect so we can visually confirm position/size in real time.

2) Instrument key metrics (DEBUG logging)
   - Log: `uiView.bounds`, `textContainer.size`, `textContainerInset`, `lineFragmentPadding`, `layoutManager.usedRect(for:)`, measured `accessorySize`, SwiftUI paddings (`textViewHorizontalPadding`, `accessoryTrailingPadding`), and the final `exclusionRect`.

3) Validate container coordinate math
   - Switch to `textContainer.size` as the authoritative container width/height.
   - Call `layoutManager.ensureLayout(for:)` before reading `usedRect`.

4) Eliminate implicit side margins
   - Set `textContainer.lineFragmentPadding = 0`. Update placeholder leading accordingly.

5) Correct horizontal overlap width
   - Compute overlap as: `overlapWidth = max(0, accessorySize.width - max(0, accessoryTrailingPadding - textViewTrailingPadding))`.
   - This reserves only the region that actually intrudes into the text container.

6) Anchor vertically to used text height
   - `exclusionHeight = accessorySize.height + collisionGap`.
   - `y = max(0, min(textContainer.size.height - exclusionHeight, usedRect.height - exclusionHeight))`.
   - This places the rect right under the active line instead of the absolute container bottom.

7) RTL
   - Mirror horizontally: `xRTL = 0`; `xLTR = max(0, textContainer.size.width - overlapWidth)`.
   - Recompute using the same horizontal delta correction.

8) Validate dynamic updates
   - Recompute on: text change, bounds change, Dynamic Type changes, accessory size change, and layout direction change. Avoid animations to prevent jumps.

### Implementation plan (small, localized edits)

Files:
- `ComprehensionEngine/Views/Shared/GrowingTextView.swift`
  - Set `textView.textContainer.lineFragmentPadding = 0` (in `makeUIView`).
  - Add new inputs: `textViewHorizontalPadding: CGFloat`, `accessoryTrailingPadding: CGFloat`.
  - Replace `updateExclusionPath` to use `textContainer.size` and `layoutManager.usedRect(for:)` as described above.
  - In DEBUG builds, draw the exclusion rect overlay for verification.

- `ComprehensionEngine/Views/ChatInputView.swift`
  - Pass `textViewHorizontalPadding = AppSpacing.Component.inputPadding - 12` and `accessoryTrailingPadding = 6`.
  - Ensure the measured `accessorySize` excludes extra paddings (measure the HStack content only, or subtract known paddings if needed).

Constants:
- `collisionGap = 6` (tunable), corner radius = `8`.

### Test checklist

- Long text: earlier lines full width; last line floats above controls with ~6pt gap (no right‑side dead zone across all lines).
- Delete text: gap disappears; no layout jump.
- Max height: internal scrolling kicks in; exclusion still prevents overlap.
- Dynamic Type L–XXL: no clipping or truncation.
- Rotation + RTL: rect mirrors correctly, no over‑reservation.
- VoiceOver: mic/send accessibility unaffected.

### Rollback

- Revert to prior commit if any regression: remove new params, restore symmetric insets, and clear `exclusionPaths`.


