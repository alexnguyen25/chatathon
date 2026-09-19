# PulsePlan synthetic showcase

This repository is a hackathon prototype for a privacy-first, calendar-aware
stress monitor. It demonstrates a pipeline rather than a medical product:

`synthetic biometric signal → descriptive change window → calendar context → voluntary planning prompt`

## Product intent

The demo joins minute-level heart-rate (HR) and heart-rate variability (HRV)
with a work calendar, highlights a sustained synthetic change, and proposes one
voluntary calendar-aware action. It does not determine stress or its cause.

## Current prototype

The generated data intentionally uses a scripted Monday, 9am–5pm scenario so
the presentation is deterministic:

- 11:00–12:00 is Design Review, followed by an open 12:00–12:30 gap before Lunch.
- HR rises from roughly 72 BPM to the low 90s while HRV declines from roughly 65ms to the low 40s.
- The score fires only after a 20% HRV drop persists for at least 15 minutes.
- HRV recovers during the following calendar gap; later mild dips are not
  treated as episodes.

The UI renders the timeline, a synthetic observation, and a contextual planning
prompt. The deterministic fallback works without exposing an API key.

## Engineering guardrails

- This is synthetic demonstration data, not a diagnostic or health tool.
- Avoid framing HRV as a definitive measure of emotional state; call it a
  signal that can support a voluntary suggestion.
- Keep persistence checks: one noisy reading must never trigger an alert.
- Preserve the calendar context in actions. “Move the 3pm 1:1 by 15 minutes”
  is useful; generic wellness advice is not.
- Any production LLM call must happen server-side with consent, least-privilege
  calendar access, and no manager-facing individual health telemetry.

## Run locally

Open `index.html` in a browser, or serve this folder with any static web server.
No install step is required.
