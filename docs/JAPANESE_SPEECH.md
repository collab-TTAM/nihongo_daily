# Japanese system speech

The speech button is explicit-tap only. It never starts automatically when a
lesson opens, and speech does not create a saved recording or learner study
credit.

## Platform behavior

- Web uses the browser Speech Synthesis API and an installed Japanese voice.
- Windows launches the built-in Windows PowerShell host and .NET
  `System.Speech.Synthesis.SpeechSynthesizer`, selecting an enabled `ja` or
  `ja-*` voice installed for the current Windows user. The fixed script is
  UTF-16LE encoded; learner text is sent through redirected standard input,
  never interpolated into the command line or a script path.
- Other native platforms report speech as unsupported until a reviewed native
  adapter is added.

Windows speech is local system synthesis, not an original recording. A Windows
installation without an enabled Japanese voice returns the explicit
`noJapaneseVoice` state; install a Japanese speech voice through Windows
language settings and retry. PowerShell/.NET or audio-device failures remain
safe fixed UI errors. Stop/dispose terminates the owned PowerShell process.
No audio is uploaded, recorded, stored, or sent to a paid provider.

## Bounds and learning semantics

Text whitespace is normalized and input is limited to 8192 UTF-16 code units;
empty text and remaining control characters are rejected. Windows repeats the
same bounds before synthesis. The native process receives only the bounded text
on stdin and emits fixed status markers; stdout/stderr never contain learner
text or platform exception details.

System TTS is a pronunciation aid only. It is not reviewed JLPT listening
material, a listening-comprehension assessment, an attendance signal, or proof
that a learner listened. It cannot unblock `LISTENING_READING`, create study
minutes, mark a plan block complete, update mastery, or change SRS state.
Reviewed/licensed recordings and hosted availability require a separate gate.
