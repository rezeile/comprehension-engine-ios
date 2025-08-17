### Goal
Remove the bottom navigation bar (TabView) from the chat screen while preserving Voice mode (via the mic button) and Settings (via the top-right gear button). Ensure no regressions.

### Current State (as of this plan)
- `ContentView` hosts a `TabView` with three tabs:
  - `ChatView` (Chat)
  - `VoiceModeView` (Voice)
  - `SettingsView` (Settings)
- `ChatView` already presents `VoiceModeView` as a sheet when the mic icon in `ChatInputView` triggers `onVoiceMode`.
- `ChatView` renders a custom `ChatNavigationBar` with a gear icon, but `onShowSettings` is currently a no-op.
- `ComprehensionEngineApp` injects `AudioManager.shared` and `ChatManager.shared` into the root view.

References:
```1:31:ComprehensionEngine/Views/ContentView.swift
struct ContentView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView() ... .tag(0)
            VoiceModeView() ... .tag(1)
            SettingsView() ... .tag(2)
        }
    }
}
```

```46:81:ComprehensionEngine/Views/ChatView.swift
.overlay(alignment: .top) {
    ChatNavigationBar(
        title: chatManager.currentSession.title,
        selectedModel: $chatManager.selectedModel,
        onNewChat: { showingNewChatAlert = true },
        onShowSettings: { }
    )
}
...
.safeAreaInset(edge: .bottom) {
    ChatInputView(
        text: $inputText,
        onSend: sendTextMessage,
        onVoiceMode: { showingVoiceMode = true }
    )
}
.sheet(isPresented: $showingVoiceMode) { VoiceModeView() }
```

### High-Level Approach
1. Remove the bottom navigation by simplifying `ContentView` to only host `ChatView` as the root view (no `TabView`).
2. Wire the top-right gear button in `ChatView` to present `SettingsView` as a sheet.
3. Keep Voice mode behavior unchanged: continue presenting `VoiceModeView` from `ChatView` when the mic is tapped in `ChatInputView`.
4. Validate previews and environment object injection remain intact.

### File-by-File Edit Plan (no changes applied yet)
- `ComprehensionEngine/Views/ContentView.swift`
  - Remove `@State private var selectedTab`.
  - Replace the `TabView` body with a simple `ChatView()`.
  - Remove `.accentColor(.blue)` if it only targeted the `TabView`.

- `ComprehensionEngine/Views/ChatView.swift`
  - Add `@State private var showingSettings = false`.
  - Pass `onShowSettings: { showingSettings = true }` to `ChatNavigationBar`.
  - Add `.sheet(isPresented: $showingSettings) { SettingsView() }` at the same level as the existing Voice sheet.

- `ComprehensionEngine/ComprehensionEngineApp.swift`
  - No functional changes; it will continue to inject `AudioManager.shared` and `ChatManager.shared` into the root `ContentView`.

### Why this is Safe
- Eliminates the only `TabView` in the codebase (scoped to `ContentView`), so the bottom bar disappears only where intended.
- Voice mode is already sheet-driven from `ChatView` and remains unaffected.
- Settings will be presented from the existing gear icon, restoring access to the same screen the Settings tab provided.
- Environment objects are injected at the app root and flow down to all views as before.

### Acceptance Criteria
- Bottom navigation bar is not visible anywhere in the app’s initial chat experience.
- Tapping the mic icon in the chat input opens `VoiceModeView` as before.
- Tapping the gear icon in the chat’s top-right opens `SettingsView` in a modal/sheet.
- No crashes and no broken references to `selectedTab` or `TabView`.
- Previews compile for `ContentView`, `ChatView`, and `VoiceModeView`.

### Test Plan
Manual checks on device/simulator:
- Launch app → Chat screen shows with no bottom bar.
- Type and send a message → works; list autoscrolls; keyboard interactions OK.
- Tap mic → `VoiceModeView` sheet appears; record/stop/send flows remain functional.
- Dismiss voice → returns to chat unchanged.
- Tap gear in chat → `SettingsView` sheet appears; interact with toggles and voice picker.
- Dismiss settings → returns to chat; state persists appropriately.
- Light/Dark mode visual pass; iPhone small/large sizes; rotation (if supported);
  verify safe areas and input bar remain correct.

### Potential Edge Cases / Mitigations
- If any code elsewhere expects a `TabView` environment, verify there are no dependencies (none found in repo).
- If `VoiceModeView` also needs Settings access via its gear button, consider mirroring the sheet presentation there (not required by this task; can be a follow-up).

### Rollback
- Revert `ContentView` to the previous `TabView` implementation and remove the new settings sheet from `ChatView`.





