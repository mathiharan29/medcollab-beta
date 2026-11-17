# Using Vocle voice commands in noisy areas

## Check what Vocle is about to do

Read the confirmation card before tapping Open, Send or Create draft. Check the person's name, the conversation or ward, and the bed details. If two people share a name, select the right person from the choices before confirming. Cancel if any detail is wrong, the wording has picked up another conversation, or the proposal came from nearby speech.

In the synthetic background-speech test, Vocle offered to open Alex's chat even though the test supplied no foreground command. Cancelling left the app and its data unchanged. That means a confirmation card can be legitimate-looking even when nobody meant to issue a command. [Hosted smoke evidence](https://github.com/mathiharan29/medcollab-beta/actions/runs/44093932819/artifacts/14333098373)

## When to repeat, rephrase or use the screen

- If the first interpretation is wrong and you can move away from nearby conversations, try again in the quieter spot. Check the new confirmation card before acting.
- Say the ward and channel together, for example “Open chat with Cedar Ward General.” Saying just “General” produced a request for clarification even when the words were heard correctly.
- If a person's name repeatedly comes back wrong, choose the person on screen. In the tests, Bala and Priya were repeatedly misheard. The slower Bala recording also failed. The tests do not establish that speaking more slowly will fix a name.
- For a handoff, verify the recipient, beds and summary in the draft editor. Use the manual form when voice recognition leaves out or changes a detail.

## What the noise tests showed

The Alex chat and handoff commands both worked in the matched quiet recordings. With background voices at moderate interference, Alex's chat still opened correctly, but the handoff picked up the same extra words in both test runs. With stronger overlapping speech, both commands failed. The ventilation test fared better at moderate interference. Equipment and movement also changed a bed instruction in one run. Nearby speech deserves particular attention because it can sound like part of your command.

If several people are speaking nearby and the action matters, use the screen. If Vocle heard the correct person but added words or changed a bed, cancel and use the manual form or try again in a quieter spot. [First full run evidence](https://github.com/mathiharan29/medcollab-beta/actions/runs/44093981592/artifacts/14333463539), [repeat evidence](https://github.com/mathiharan29/medcollab-beta/actions/runs/44093981592/artifacts/14334977030)

The tests used prerecorded synthetic speech and controlled interference on a hosted Android emulator. Actual rooms, phones, microphones, voices and offline recognition can behave differently. These results do not establish a clinical reliability threshold. [Technical investigation](VOICE-ASSISTANT-RELIABILITY.md), [clean failure evidence](VOICE-ASSISTANT-CLEAN-FAILURES.md)
