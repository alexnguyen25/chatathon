# Pipeline overview (for teammates / their Claude Code sessions)

This covers the data + LLM pipeline Jason built. Frontend work is
separate and being done by someone else — this doc explains what feeds
into it, not how to build it.

## Repo layout

- `/pipeline/` — the four scripts, run in order: `generate_mock_data.py` -> `analyze_stress.py` -> `generate_suggestion.py`, orchestrated by `run_demo.py`
- `/data/` — everything the pipeline reads/writes: `calendar.json`, `biometrics.csv`, `detected_episodes.json`, `suggestions.json`. This is the contract — whatever consumes this (web, iOS-style mockup, whatever) should read from here and not need to know how it was generated.
- `/web-dashboard-archive/` — the original HTML dashboard. Not the active frontend right now (team is emulating an iOS-style UI instead), kept here in case it's useful as a reference or fallback later. Not being actively developed.
- `/docs/` — this file, plus the README

## What's in the data

## The three files you're pulling from

**`calendar.json`** — one workday, 8 meetings, each tagged with a `type`
(team / high_focus / high_stakes / one_on_one / focus_time) and a
`back_to_back` flag (true if it started within 5 min of the prior meeting
ending). This is the "what was happening" layer.

**`biometrics.csv`** — per-minute HR + HRV from 9:00am-5:00pm. One
scripted stress episode is baked in: HRV declines steadily from ~1:00pm,
bottoms out around 2:00pm, recovers by ~3:00pm. This is real synthetic
data, not random noise — the dip is engineered to be detectable, so don't
"fix" it or regenerate it as random values, or the detection breaks.

**`suggestions.json`** — the final output. Each entry is one detected
stress episode plus:
- `duration_minutes`, `meetings_in_window`, `any_back_to_back`, `next_event` — pulled straight from the calendar/biometric join, no LLM involved
- `suggestion` — the actual LLM-generated text (or fallback text if the API call failed)
- `source` — either `"gemini-3-flash-preview"` (live model output) or `"fallback"` (canned text). **Always show this distinction in the UI** — don't present fallback text as if it came from the model.
- `baseline_hrv` / `threshold_hrv` — precomputed so you never have to recalculate this in JS

## What the pipeline actually did (in order)

1. **Ingest** — joined the calendar and biometric streams by timestamp
2. **Score** — flagged where HRV stayed below 80% of the day's baseline for 20+ minutes straight (that's the "sustained" bar — a brief dip doesn't count)
3. **Context** — matched the flagged window against the calendar to pull in which meetings, whether they were back-to-back, what's next
4. **Act** — sent only that structured summary (never the raw time-series) to the LLM, which wrote one specific suggestion tied to the actual pattern

## What to actually show a judge

The story is: **a stress pattern was detected → it's grounded in real calendar context → the AI gave one concrete, self-directed action.** The chart's value is proving the detection isn't fabricated — the shaded window should visibly line up with the HRV dip. The suggestion card is the payoff. Everything else (table view, hourly readings) is supporting detail for someone who wants to double check the math, not the headline.

## Known cleanup needed

The archived dashboard's suggestion card says "no Claude API credentials
were available" and its pipeline footer still says "Claude writes the
next step" — leftover copy from before the Gemini switch. Low priority
since that dashboard isn't the active frontend, but worth fixing if it's
ever reused so it doesn't say the wrong provider.

## For the iOS-style frontend specifically

Read from `/data/suggestions.json` — it already has everything needed
per episode (duration, meetings, back-to-back flag, next event, the
suggestion text, and the `source` field distinguishing live-model output
from fallback text). Don't re-derive any of this from the raw CSV/JSON —
that math is already done and tested.
