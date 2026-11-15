# NIKO direct hands-free voice on iPhone (no Siri)

## Product decision

The product must be invoked as **NIKO**, not through Siri. Siri, App Intents, App Shortcuts and Siri handoff are explicitly out of scope. The primary experience is a voice-first personal assistant, not a WhatsApp-style chat screen.

The agreed user flow is:
1. The user opens NIKO and explicitly starts a clearly visible listening session.
2. The user may leave NIKO, lock the phone, or use other apps.
3. While iOS continues to grant the app its permitted background audio execution, a local wake-word detector listens for "NIKO".
4. On detection, NIKO captures the command, sends only the required audio/text to the authenticated NIKO service, and speaks the response.
5. The user can stop listening immediately from NIKO; the active microphone state must be clearly indicated.

## Platform feasibility and non-negotiable limits

iOS does not provide ordinary third-party apps with unrestricted, permanent background execution or a general-purpose custom hotword entitlement. A user-started audio session and the audio background mode may allow some continued audio processing while the app is backgrounded, but this is conditional: iOS can interrupt or suspend the app, calls and other audio sessions can take priority, battery impact must be managed, and App Review may reject misuse of background audio.

Therefore:
- Never claim guaranteed wake-word availability after force-quit, reboot, OS suspension, or an audio-session interruption.
- Do not disguise a wake-word listener as music playback or use background audio mode solely to evade platform rules.
- Investigate Apple's current background-audio rules and App Review requirements before implementation.
- Prefer on-device wake-word detection so idle microphone audio is not streamed to the backend.
- Keep the microphone permission, active listening state, stop control, privacy explanation, and interruption/recovery behaviour explicit.
- If iOS does not permit the required background listening behaviour for the intended app use, report the limitation and present a truthful fallback rather than shipping a covert or policy-violating workaround.

## Native iOS implementation plan

1. Add and track the real Flutter iOS Runner/Xcode project; do not create orphan Swift files.
2. Build a Swift native audio-session manager with explicit start/stop lifecycle and interruption handling.
3. Evaluate a maintained on-device wake-word engine that supports custom "NIKO" models and iOS deployment. Document licensing, model size, CPU/battery use, false-accept and false-reject rates.
4. Bridge wake events and audio capture to Flutter using a typed platform channel.
5. Implement authenticated, short-lived voice requests; do not stream idle audio to the server.
6. Use a speech provider abstraction for transcription and spoken replies, with Arabic dialect, English and Turkish support.
7. Add macOS CI for iOS simulator build and unit tests; physical-device testing remains mandatory.

## Acceptance tests

- Start listening from NIKO after explicit microphone permission.
- Switch to other apps and verify whether the session continues under supported iOS conditions.
- Lock the screen and measure wake-word detection reliability, response latency and battery drain.
- Verify no idle microphone audio is uploaded.
- Verify stop control, permission denial, incoming call, audio interruption, network loss, app suspension and force-quit behaviour.
- Verify the spoken response belongs to the signed-in user and cannot expose another user's content.
- Test on supported physical iPhone models and iOS versions; simulator-only success is insufficient.

## Privacy

Raw wake-word processing should remain on device. Capture and upload a command only after local wake-word detection and according to the user's explicit settings. Do not persist raw voice recordings by default. Redact tokens, prompts, transcripts and personal content from operational logs.
