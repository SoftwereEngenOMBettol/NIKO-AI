# NIKO hands-free voice on iPhone

## Product requirement

NIKO must not feel like a WhatsApp-style chat app. The primary experience is a voice-first personal assistant that the user can invoke while the phone is nearby without navigating into the chat screen. The user explicitly wants to call to NIKO from a distance.

## iOS platform constraint (important)

A third-party iOS app cannot freely run a hidden, always-on custom wake-word detector in the background like a dedicated smart speaker. iOS controls background execution and microphone access; continuous background listening is restricted, drains battery, and requires visible system microphone permission/indicators. We must not promise a custom always-listening "NIKO" hotword until Apple platform policy and an approved implementation path support it.

## Supported implementation path

1. **Siri / App Intents first:** expose a NIKO voice action using Apple's App Intents and App Shortcuts. The user can invoke it through Siri (for example, "Hey Siri, ask NIKO ...") without manually opening the NIKO interface first, subject to the iOS version and Siri language/region support.
2. **Handoff into NIKO voice session:** the App Intent passes the recognized request to the app/service, starts a voice interaction, and returns a spoken response using the system speech output where allowed.
3. **Foreground voice session:** while NIKO is active, support continuous turn-taking with clear start/stop controls, interruption handling, and a visible microphone state.
4. **Lock-screen entry points:** evaluate supported Shortcuts, Action Button, widgets and notifications as quick launch paths. These are entry points, not hidden always-on listening.
5. **Fallback:** if Siri/App Intents are unavailable or a user has disabled Siri, provide a clearly labeled manual voice button.

## Acceptance criteria

- The user can invoke a NIKO action through Siri without first navigating to the NIKO chat screen.
- A recognized spoken request is passed to the NIKO backend and the reply is spoken back.
- Permission denial, offline state, unsupported Siri locale and backend failure have understandable spoken/visible fallbacks.
- Microphone use is explicit, visible and stoppable; no covert recording.
- The feature works on a physical iPhone and is tested against supported iOS versions, not just a simulator.
- App Intents and App Shortcuts are integrated into the actual Xcode target and signed app. A Swift source file not included in the Xcode target does not count as implementation.

## Deferred until the iOS project target exists

The current repository's mobile source is Flutter and does not yet contain a tracked mobile/ios/Runner Xcode project. Therefore, do not add orphan Swift files and claim Siri integration. First generate/commit the iOS Runner project, then implement an App Intents extension/target (or an app-integrated AppIntent where supported), URL/deep-link or shared-container handoff, entitlements, usage descriptions, and macOS CI.

## Privacy

Do not record or stream microphone audio continuously in the background. Process audio only after a user-initiated Siri action or while a clearly visible active voice session is running. Never store raw audio unless the user explicitly enables a feature that needs it.
