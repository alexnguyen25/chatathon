# Meeting-load stress monitor

This repository is a hackathon prototype for a privacy-first, calendar-aware
stress monitor. It demonstrates a pipeline rather than a medical product:

`synthetic biometric signal → rolling baseline score → calendar context → actionable employee nudge`

## Product intent

People often notice stress only after a meeting-heavy day has already affected
their focus. The demo joins minute-level heart-rate (HR) and heart-rate
variability (HRV) readings with a work calendar, detects a sustained HRV drop,
and proposes one immediate calendar-aware action. Messages are always directed
to the employee, never to a manager.

## Current prototype

`index.html` is a dependency-free static frontend. It intentionally uses a
scripted Tuesday, 9am–5pm scenario so the presentation is deterministic:

- 9:30–11:30 contains a standup, manager 1:1, and all-hands with no breaks.
- HRV declines from roughly 64ms to 36ms while HR rises.
- The score fires only after a 20% HRV drop persists for at least 15 minutes.
- HRV recovers during the following calendar gap; later mild dips are not
  treated as episodes.

The UI renders the timeline, the detected episode, and a contextual nudge for
the next meeting. The current “Generate suggestion” experience is intentionally
local and deterministic so it works without exposing an API key in the browser.

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
