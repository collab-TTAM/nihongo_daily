# Japanese system speech

Nihongo Daily can optionally read the currently displayed Japanese text using the browser's built-in Web Speech synthesis.

## Scope and behavior

- Playback starts only after an explicit learner tap. The app never autoplays.
- The Web adapter selects a voice whose language is \`ja\` or begins with \`ja-\`, sets the utterance language to \`ja-JP\`, and uses a slightly reduced speaking rate.
- Vocabulary reads its kana reading when present; grammar reads the pattern and current Japanese examples; a reading passage reads only its Japanese passage text.
- Each request is bounded to 8,192 characters. Empty/invalid text, an unsupported browser and a missing Japanese voice return separate fixed outcomes. Raw browser exceptions are never shown.
- A new request replaces the previous utterance. Stopping or leaving the detail/passage disposes the button and cancels playback.
- Native Windows and other non-web targets use an explicit unsupported adapter in this increment. No native voice package or platform SDK was added.

## Important limitations

This is **system-generated speech**, not a reviewed recording or an audio asset from the curriculum. The browser/OS must already provide a Japanese voice; voice availability and pronunciation quality vary by device. If the voice list is still loading, retry after the browser has populated it.

Original curriculum audio is still not integrated, no audio is downloaded or stored, and this is not a listening assessment. Speech playback does not create study events, quiz attempts, mastery, progress, or sync. No microphone, speech recognition, network request, paid AI provider, account token, or learner data is involved.

The browser capability check runs in Chrome CI. iOS browser voice behavior and native Windows speech remain unverified and require separate platform work before claiming cross-platform audio support.
