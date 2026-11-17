# Vocle Voice Assistant noise and reliability

## Clean-audio investigation

The Phase 2 full hosted Actions run executed 55 attempts on Android API 35. It recorded 26 passes, 28 transcript mismatches and one parser mismatch. The audit joins every attempt to the unchanged WAV and records the exact phrase, result, target, voice, synthesis speed, duration, amplitude, format, recognizer status and app outcome. The failed set includes the already-noisy Bala sample and the quiet Search sample. [Phase 2 run](https://github.com/mathiharan29/medcollab-beta/actions/runs/44058584613), [original evidence](https://github.com/mathiharan29/medcollab-beta/actions/runs/44058584613/artifacts/14317643071), [all 29 failed attempts](VOICE-ASSISTANT-CLEAN-FAILURES.md)

- The original short Bala and longer Doctor Bala recordings failed both repetitions. Bela also failed. The name was absent or changed in Android's final text before the parser ran. Alex passed across repetitions with the same title in its longer phrasing. The title alone cannot explain the failures. A slower Bala variant and a distinct Piper voice also failed. Those fixtures changed multiple factors, so this comparison cannot isolate pronunciation, rate or the recognizer model.
- Priya failed across the original, paused and alternate-voice handoff recordings. Android returned phrases including “I'm not bad Kevin” and “hand off bed 7 to printer.” Alex's comparable handoff with a bed passed. This locates the observed Priya failure upstream of draft handling.
- None of the failed WAVs had clipped samples. The quiet Search recording was the lowest-amplitude failure at about 520 PCM units RMS. The nominal Search recording passed, but the two recordings also differ in voice and synthesis. Long and short failures both occurred. The corpus mixes commands, names and voices, so rates by voice or duration are descriptive.
- Across the original 54 speech attempts, 24/31 eSpeak outcomes and 5/23 Piper outcomes failed. The nominal clean WAVs under three seconds had 12/22 failures and the longer files had 15/30. Clip duration includes padding. Differences in command, speaking style, name and repetition prevent a causal comparison between synthesis engines or durations.
- Android returned “open chat with General” correctly. Vocle offered clarification because its scorer recognizes the stripped channel alias in the word list but requires a name hit. “Cedar Ward General” qualified by space passed. [Name scoring](../../medcollab-app/lib/features/voice_bot/domain/voice_command_parser.dart)

## Experimental design and gates

The original Phase 2 selection retains its strict transcript and app checks. The Noise & Reliability selection uses the same GitHub-hosted Linux runner, Android API 35 default recognizer and ParcelFileDescriptor input. Emulator audio is disabled and online recognition is allowed. The app receives the actual native final callback. It confirms only a matching intent, exact seeded target or choice set, and required payload. The native probe and Voice Bot run on the same emulator. [Android audio source](https://developer.android.com/reference/android/speech/RecognizerIntent#EXTRA_AUDIO_SOURCE)

| Case | Planned coverage | Gate fixed before hosted execution |
|---|---|---|
| FR-AST-41 | Repeat original Alex DM, Alex bed-12 draft, Needl and Profile. Repeat diagnostic names, General and quiet speech. Compare Alex chat and draft against matched-level clean references and controlled interference | All four original functional anchors and Alex DM under +10 dB ventilation must finish with the expected app action. Safe exploratory misses are recorded as failed fixture outcomes. |
| FR-AST-42 | Repeat unknown, ambiguous and incomplete commands. Check silence, equipment-only audio, background command audio and two foreground commands mixed with competing commands | Verify unchanged route and persisted state before confirmation. Cancel unexpected proposals through the UI and verify no side effects. Any unexpected actionable proposal counts as hazardous even if cancelled. Every safety or infrastructure assertion must pass. |

For correctly understood audio, the test checks the exact route, conversation ID, single DM lookup or one persisted draft and its form. Wording can differ while the independently verified action stays correct. The safety test declines differently resolved recipients. The duplicate-confirmation defect and repeated-final event coverage remain in the existing transcript tests. The audio suite verifies the effects of one deliberate confirmation.

Two base WAVs use a foreground gain of 0.48 for every mixed level and its matched-clean reference. The original unit-gain fixtures still run separately. Noise is scaled in the original active speech window, from the first to the last absolute sample of at least 128 PCM units. The generator measures SNR after integer quantization, rejects clipping and verifies the committed SHA-256 before recognition. Babble uses overlapping synthetic, noncommand utterances at +20, +10, +5, 0 and −5 dB. Ventilation and equipment/steps use deterministic low-frequency noise, tones and pulses at +10 and 0 dB. Targeted competing-command samples run at −5 dB. These sounds approximate selected acoustic conditions with wholly synthetic signals. [Generator](../../tests/functional-regression/voice-audio/generate-noise.py), [fixture manifest](../../tests/functional-regression/voice-audio/noise-manifest.json)

Automatic smoke runs on relevant master pushes alongside the existing prerecorded smoke. The full matrix uses Feature Regression → voice-assistant-noise, with two repetitions for designated fixtures by default. The artifact publishes native evidence and per-attempt reports. WER normalizes letter case, punctuation, Doctor/Dr, handoff spacing, and the corpus's seven/twelve spellings. Missing finals count as deletions. Controls without a reference have no WER. Latency runs from startListening to the terminal callback. These small synthetic cells establish no clinical thresholds.

Run the following from the repository root to regenerate the 24 derived WAVs and verify all 39 planned fixtures against the manifest. The automatic and full Android runs perform the same verification on GitHub Actions.

```sh
python tests/functional-regression/voice-audio/generate-noise.py /tmp/vocle-noise
```

## Hosted results

The automatic smoke passed both hosted jobs. The original prerecorded smoke recorded 6/6 passes. The new noise smoke recorded 6/6 on its own profile, including the +10 dB ventilation fixture opening the exact Alex DM. Background-only speech triggered an Alex DM proposal. The test cancelled it and verified unchanged navigation and persisted state. [Master smoke](https://github.com/mathiharan29/medcollab-beta/actions/runs/44093932819), [noise smoke evidence](https://github.com/mathiharan29/medcollab-beta/actions/runs/44093932819/artifacts/14333098373)

The first full run recorded 30 passed fixture outcomes, 28 failed fixture outcomes and one blocked attempt, with all 59 planned native sessions represented. It returned final speech for 55/56 reference utterances, matched the normalized transcript in 29/56, matched intent in 29/55 and measured correct entity resolution in 23/47. The case failed its functional gate because the first original Alex session reached ready and consumed all 108,418 bytes, but sent no terminal callback by 18 seconds. The second original Alex session completed. The timeout remains a separate blocked attempt. [First full attempt](https://github.com/mathiharan29/medcollab-beta/actions/runs/44093981592/attempts/1), [first full artifact](https://github.com/mathiharan29/medcollab-beta/actions/runs/44093981592/artifacts/14333463539)

On the original PCM, Alex's bed-12 draft, Nurse Station Needl and Profile each passed 2/2. Unknown Zelda and incomplete “open chat” each produced safe clarification twice. Both Jordan attempts showed the two exact choices, then opened only the selected DM after confirmation. The original short and long Bala, Bela, both selected Priya recordings, the quiet Search and bare General each passed 0/2.

### Paired comparison from the first full run

Each row compares the same Alex DM and Alex bed-12 audio at the same foreground gain. The WER denominator is words across both commands. End-to-end outcomes include the actual app state checks.

| Condition | WER | Expected outcome | Median recognition latency |
|---|---:|---:|---:|
| Matched clean | 0/20 | 4/4 | 885 ms |
| Babble +20 dB | 0/10 | 2/2 | 824 ms |
| Babble +10 dB | 4/20 | 2/4 | 1,411 ms |
| Babble +5 dB | 10/10 | 0/2 | 1,642 ms |
| Babble 0 dB | 20/20 | 0/4 | 1,561 ms |
| Babble −5 dB | 10/10 | 0/2 | 1,289 ms |
| Ventilation +10 dB | 0/10 | 2/2 | 836 ms |
| Ventilation 0 dB | 6/10 | 1/2 | 1,044 ms |
| Equipment and steps +10 dB | 1/10 | 1/2 | 954 ms |
| Equipment and steps 0 dB | 0/10 | 2/2 | 1,258 ms |

The first tested babble condition with a miss was +10 dB. Alex's chat passed both attempts at that level. Both handoff attempts returned “hand off bed 12 to Alex the sky.” The target matched but the payload changed, so the app exposed a hazardous draft proposal. The test cancelled both. Ventilation lost one of two actions at 0 dB. The equipment result was nonmonotonic across the two levels. These cells use one deterministic masker per condition, a few repetitions and fixed execution order. They are too small and correlated for population uncertainty estimates.

All 58 attempts that reached the safety checks had zero unintended navigation or persisted side effects. The three hazardous proposals comprised the two contaminated handoffs and the background-only Alex chat. Strong competing-command mixtures inserted parts of the background command, but neither mixture produced an actionable proposal on this run. Repeated original Bala and Priya still failed before application parsing. The bare General parser failure and existing FR-AST-25 duplicate-confirmation defect remain separate application findings.

### Exact-commit repeat

Both cases passed their functional and safety gates on the repeat, which retained 30 passed fixture outcomes and 29 exploratory failures. All 59 descriptors reached EOF in both attempts. The repeat returned final speech on 56/56 reference utterances, with 29/56 exact normalized transcripts, 95/254 word errors, 30/56 correct intents, 24/48 correct measured entities and 27/56 correct end-to-end speech outcomes. Median recognition latency fell from 1,047 ms to 557 ms. These are measured Android callback times, including recognizer processing, and exclude the time a person would spend speaking or reviewing a proposal. [Full repeat](https://github.com/mathiharan29/medcollab-beta/actions/runs/44093981592/attempts/2), [repeat artifact](https://github.com/mathiharan29/medcollab-beta/actions/runs/44093981592/artifacts/14334977030)

Both runs matched the same pattern for babble and ventilation. Across the two runs, the matched clean clips passed 8/8, +20 dB babble passed 4/4, +10 dB babble passed 4/8, and +5, 0 and −5 dB babble passed 0/16. Ventilation passed 4/4 at +10 dB and 2/4 at 0 dB. Equipment at 0 dB changed from 2/2 to 1/2. In the repeat, Android returned “handoff at 12:00 to Alex,” producing a draft proposal with the wrong bed payload. Over both full attempts, seven proposals were hazardous and cancelled, and zero incorrect actions were observed in the 117 attempts with verified safety checks. The first timeout remains blocked and outside that denominator.

The archived JSON includes exact transcripts, intent, entity IDs, per-command and per-condition rates, paired WER and action deltas, and native latency. The safety checks verify unchanged state around incorrect or unconfirmed proposals and exact app postconditions after a deliberately correct confirmation. The [user guide](VOICE-ASSISTANT-USER-GUIDE.md) explains what these observations mean when using the app.
