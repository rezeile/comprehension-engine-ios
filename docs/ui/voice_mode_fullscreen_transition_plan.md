### Goal
Create a center-origin, full-screen Voice Mode presentation from the chat screen that expands smoothly from the center (no bottom-sheet behavior) and dismisses with a smooth reverse animation. Do not change Voice Mode functionality (listening UI, controls, or state) beyond presentation/transition mechanics.

### Current Behavior
- `ChatView` presents `VoiceModeView` via `.sheet(isPresented: $showingVoiceMode) { VoiceModeView() }`, which uses a page/bottom sheet style on iPhone.
- This results in a slide-up motion with the underlying screen slightly visible at the top edge during presentation.

References:
```1:90:ComprehensionEngine/Views/ChatView.swift
.sheet(isPresented: $showingVoiceMode) {
    VoiceModeView()
}
```

### Proposed Approach
Replace the `.sheet` presentation for Voice Mode with a custom full-screen overlay that:
- Covers the entire screen immediately with an opaque background so the chat screen is never visible during/after presentation.
- Uses a center-origin expansion animation (scale+opacity) for entry, and a symmetric reverse for exit.
- Keeps `VoiceModeView` unchanged; only wraps it in a presentation container.
- Preserves environment objects by rendering inside the same SwiftUI hierarchy.
- Avoids safe-area layout shifts by not altering insets (overlay sits above the chat UI).

#### High-level Mechanics
- Add a `VoiceModeOverlay` component that takes a `Binding<Bool>` for presentation and hosts `VoiceModeView` inside a full-screen `ZStack` with an opaque background and a custom transition.
- Animate with `.easeInOut(duration: 0.26)` (within the 250–300 ms target) and use an asymmetric transition:
  - Insertion: `.scale(scale: 0.92, anchor: .center)` combined with `.opacity` from 0 → 1
  - Removal: same in reverse
- Apply `.ignoresSafeArea()` and a fully opaque background color (e.g., `AppColors.background`) to prevent any underlying view peeking.
- Optional: light shadow/elevation on the expanding layer to emphasize elevation (kept subtle).

#### Dismissal / Navigation Integrity
- Preserve prior behavior where users could dismiss Voice Mode via a gesture by adding an interactive drag-down to dismiss on the overlay container (thresholded, with rubber-banding). This does not modify `VoiceModeView` functionality or controls; it is strictly presentation.
- Also support programmatic dismissal by toggling the same binding (e.g., close button if one is later added), but do not introduce new visible controls as part of this task.

### File-by-File Plan (no code changes yet)
- `ComprehensionEngine/Views/ChatView.swift`
  - Remove the existing `.sheet(isPresented: $showingVoiceMode) { VoiceModeView() }` for Voice Mode.
  - Add an overlay at the root of `ChatView` (sibling to existing UI), e.g.:
    - `.overlay { if showingVoiceMode { VoiceModeOverlay(isPresented: $showingVoiceMode) { VoiceModeView() } } }`
  - Ensure the overlay has a higher `zIndex` than other overlays (e.g., settings nav bar), e.g., `.zIndex(1000)`.
  - Keep the existing settings `.sheet` intact and unchanged.

- `ComprehensionEngine/Views/Shared/VoiceModeOverlay.swift` (new file)
  - Implement a reusable overlay presenter with parameters:
    - `isPresented: Binding<Bool>`
    - `content: () -> Content` where `Content: View` (for `VoiceModeView`)
  - Implementation details:
    - Full-screen `ZStack` with an opaque background `AppColors.background` and `.ignoresSafeArea()`.
    - Wrap `content()` in a container applying transitions:
      - `AnyTransition.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .scale(scale: 0.92).combined(with: .opacity))`
      - `.animation(.easeInOut(duration: 0.26), value: isPresented)`
    - Add interactive dismissal:
      - Attach a `DragGesture` capturing vertical movement.
      - Translate and slightly scale the content for feedback; if drag exceeds a threshold (e.g., 120 pts) and velocity is downward, set `isPresented = false` with the same animation curve; otherwise snap back.
    - Block interactions to underlying views with `.allowsHitTesting(true)` on the overlay and no transparency in background.

### Animation Details
- Entry (target ~260 ms):
  - Background: `opacity 0 → 1` (very fast ramp to 1 within 80 ms)
  - Content: `scale 0.92 → 1.0`, `opacity 0 → 1`
  - Curve: `.easeInOut`
- Exit: reverse of entry, with background `opacity 1 → 0`.

### Acceptance Criteria Mapping
- Center-expanding, full-screen transition: Implemented via scale+opacity from center with opaque full-screen background; no bottom-sheet motion remains.
- No parent visibility: Opaque background and `.ignoresSafeArea()` guarantee no peeking.
- Smooth dismissal: Reverse animation; drag-down gesture supported to mimic prior sheet dismissal feel.
- Navigation integrity: Uses the same `showingVoiceMode` binding; programmatic dismissal remains; gesture-based dismissal provided.
- Layout stability: Overlay does not affect `safeAreaInset` or layout of the chat input; no jumping.
- Works across light/dark and device sizes: Colors and layout rely on existing `AppColors` and flexible frames.

### Testing Plan
Manual tests on device/simulator:
- Tap mic in chat input → overlay expands from center to full-screen (~260 ms).
- During/after presentation, the chat screen is never visible at the top or edges.
- Drag down moderately → Voice Mode dismisses smoothly and returns to exact chat state (no flicker, no scroll jumps, input bar stable).
- Re-enter Voice Mode repeatedly; verify no memory leaks (instruments optional) and animations remain consistent.
- Light/Dark mode QA; small/large iPhone sizes.

### Rollback Strategy
- Revert `ChatView` to use the previous `.sheet` for Voice Mode.
- Remove `VoiceModeOverlay.swift` if introduced.

### Notes / Non-Goals
- Do not alter `VoiceModeView` controls, logic, or state; only wrap for presentation.
- Settings presentation remains via `.sheet` from the chat gear button.





