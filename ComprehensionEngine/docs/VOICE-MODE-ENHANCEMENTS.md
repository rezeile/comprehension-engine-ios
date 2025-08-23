## Voice Mode Enhancements

### Summary
- **Always-visible Send button** in Voice Mode (like Claude): present and enabled when there is transcript content.
- **Auto-listen on entry**: Voice Mode starts recording immediately; no initial "Tap to speak" interaction.
- **Internal transcription only**: live transcript is not rendered in the UI.
- **Press Send to submit** the internally accumulated transcript. After sending and reading the reply, Voice Mode automatically resumes listening.

### Goals
- **Frictionless capture**: minimize taps to start/continue the voice conversation.
- **Clean UI**: remove live text rendering and keep focus on the waveform/status and controls.
- **Robustness**: handle permission, empty transcript, and network/TT S errors gracefully.

### User Flows
1. Open Voice Mode
   - App checks mic permission; if granted, recording starts automatically.
   - Status shows "Ready and listening"; waveform animates to input level.
   - Send button is visible by default; disabled until there is meaningful speech captured.

2. Speak, then press Send
   - On tap, recording pauses; partial transcription is finalized into a single string.
   - Message is sent via `ChatManager.sendMessage`.
   - When the reply arrives, it is spoken (ElevenLabs if enabled, else system TTS).
   - After playback completes, recording auto-resumes so the user can continue.

3. Edge cases
   - If Send is tapped with no transcript: provide haptic + subtle toast “No speech detected”.
   - If network fails: show alert and auto-resume listening.
   - If TTS fails: show alert and still auto-resume listening.

### State Machine
- `Listening` → default on entry (mic active)
- `Finalizing` → user tapped Send; finish transcription buffer
- `Sending` → request in flight
- `Speaking` → playing assistant response
- `Error` → transient; returns to `Listening`

Transitions:
- `Listening` --Send--> `Finalizing` --ok--> `Sending` --ok--> `Speaking` --done--> `Listening`
- `Listening` --no-speech--> stay `Listening` with haptic/notice
- Any --error--> `Error` --ack--> `Listening`

### UI/UX Changes
- `VoiceModeView.swift`
  - Remove `TranscriptionDisplay` from the layout.
  - Keep the waveform/status indicator. Status text becomes **Ready and listening** while idle.
  - Make the Send button always visible (next to the mic toggle if kept, or single control set).
  - Send button enabled state reflects `hasTranscript`.
  - Haptics: light on Send; warning on empty transcript.

### Architecture/Data Flow
- `AudioManager`
  - Maintain an internal `transcriptionBuffer` (String) fed by on-device speech recognition partials.
  - Expose publishers:
    - `@Published var inputLevel: Float`
    - `@Published var isRecording: Bool`
    - `@Published var hasTranscript: Bool` (derived from buffer’s non-empty trimmed value)
  - Add API:
    - `func startRecording()` / `func stopRecording()` (existing)
    - `func finalizeTranscription() -> String` → returns trimmed buffer and clears it.

- `VoiceModeView`
  - Start listening on appear: call `audioManager.startRecording()`.
  - Observe `audioManager.hasTranscript` to enable the Send button.
  - `sendVoiceMessage()`:
    1) `audioManager.stopRecording()`
    2) `let message = audioManager.finalizeTranscription()`
    3) guard non-empty → `ChatManager.sendMessage(message)`
    4) Speak reply (ElevenLabs if enabled; else system)
    5) After playback finishes, `audioManager.startRecording()` to resume Listening

- `ChatManager`
  - No API change; continue to use `sendMessage(_:)`.

### Acceptance Criteria
- Entering Voice Mode immediately starts listening (no user tap required).
- Live transcript text is not displayed anywhere in the UI.
- Send button is visible at all times while in Voice Mode.
- Send button is disabled until there is non-empty transcript content.
- Tapping Send with content pauses recording, sends the message, plays the reply, and resumes listening when playback completes.
- Tapping Send with no content shows a non-blocking warning and does not send.

### Implementation Steps (iOS)
1. `VoiceModeView.swift`
   - Remove `TranscriptionDisplay` from the body.
   - Add `.task` or `.onAppear` to call `startRecording()` when the view appears.
   - Ensure toolbar and controls still match the existing design language.
   - Adjust `VoiceModeControls` so Send is always rendered; bind `isEnabled` to `audioManager.hasTranscript`.
   - Update status text in `VoiceWaveformView` to prefer "Ready and listening" when idle.

2. `AudioManager.swift`
   - Add `transcriptionBuffer` and `hasTranscript` computed/published property.
   - Accumulate partial results into `transcriptionBuffer` but do not publish the text to UI.
   - Implement `finalizeTranscription()` to return and clear the buffer.

3. `sendVoiceMessage()` logic in `VoiceModeView.swift`
   - Stop recording → finalize transcript → guard non-empty → send → await reply → speak → restart recording.

4. Settings and Flags
   - Add `@AppStorage("voice_auto_resume_after_reply")` default true.
   - Retain `feature_waveform_enabled` for visualization choice (waveform vs. indicator).

5. Accessibility & Feedback
   - VoiceOver labels for mic, send, and close.
   - Haptic feedback: `.light` on Send; `.warning` for empty transcript.

6. Telemetry (optional)
   - Track events: `voice_mode_open`, `voice_send`, `voice_send_empty`, `voice_reply_spoken`, `voice_error`.

### Rollout/Testing
- Unit tests for `AudioManager.finalizeTranscription()` and state toggling.
- UI tests for: auto-listen on appear, Send enabled/disabled, resume after reply.
- Manual QA checklist:
  - Mic permission gating works.
  - Empty transcript behavior.
  - Recovery after network/TT S error returns to Listening.
  - Auto-resume toggle respected.

### Notes
- These changes are additive/non-breaking to `ChatManager` and the backend API.
- The design follows the reference behavior shown in the provided screenshots while retaining our visual style.


### Additional Enhancements
- **Single primary control (Claude-style):** Replace dual mic + small arrow with one large black button.
  - **Arrow state (Send):** Default when idle/listening. Enabled only when `hasTranscript == true`. Tap to finalize transcript and send.
  - **Square state (Stop):** When the assistant is speaking, the button switches to a black square. Tap to immediately stop speech playback and return to Listening.
  - **Progress state:** While finalizing/sending/thinking, the button shows a spinner and is disabled.
- **Tap-anywhere to interrupt:** While speaking, tapping anywhere in the main Voice Mode surface also stops speech (same as tapping the square).
- **Always-listening paradigm:** No explicit mic toggle control in the primary UI. Voice Mode auto-listens on entry and resumes after speaking. Recording temporarily pauses during sending/TT S playback.
- **Haptics:** Light impact when sending; medium impact when interrupting speech; warning when attempting to send with no transcript.
- **Accessibility:** Single control labeled contextually as “Send” or “Stop speaking”. Global surface gets “Stop speaking” during playback.
- **Visuals:** Maintain current waveform/status. Status copy remains “Ready and listening” when idle, “Listening…” while actively capturing, “Thinking…” while awaiting response, and “Speaking…” during playback.

Implementation notes:
- `VoiceModeView.swift`
  - Replace `VoiceModeControls` with a single `PrimaryVoiceButton` bound to state: `isSpeaking`, `isRecording`, `isLoading`, `hasTranscript`.
  - Add `.contentShape(Rectangle)` and `.onTapGesture` over the main container to call `stopSpeaking()` when `isSpeaking == true`.
  - Logic: if `isSpeaking` → stop speaking; else if `hasTranscript` → send; else no-op with warning haptic.
- `AudioManager.swift`
  - Add `func stopSpeaking()` that stops both system `AVSpeechSynthesizer` and any active `AVAudioPlayer` (ElevenLabs audio), setting `isSpeaking = false`.
  - Ensure `startRecording()` gracefully resumes after stopping speaking.
- Acceptance criteria additions:
  - Only one primary black button is visible in Voice Mode.
  - The button shows an arrow when ready to send and a square when speaking.
  - Tapping anywhere while speaking stops playback.
  - No secondary small arrow/mic button exists.


