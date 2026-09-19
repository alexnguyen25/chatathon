# Recovery-aware scheduling

**AINU Chatathon 2026 — WHOOP track:** *a healthier future of work.*

Most wellbeing tools stop at the chart. They show you that your stress went up
and leave you to work out what to do about it. This one closes the last mile:
it detects a **sustained** physiological stress episode, works out **which
meetings caused it**, and has an LLM write **one concrete scheduling change the
person can make on their own**.

> Everything here runs on **simulated** biometrics and a simulated calendar.
> That's deliberate — see [What's real and what isn't](#whats-real-and-what-isnt).

---

## Run the demo

Run from the repo root:

```bash
pip install -r requirements.txt        # just the google-genai SDK
export GEMINI_API_KEY=...              # optional — see note below; free tier via Google AI Studio

python3 pipeline/run_demo.py           # runs all four pipeline stages, writes into /data/
```

The active frontend (an iOS-style UI, built separately from this pipeline)
reads from `/data/suggestions.json` — see [`PIPELINE_OVERVIEW.md`](PIPELINE_OVERVIEW.md)
for the full data contract. The original HTML dashboard is archived in
`/web-dashboard-archive/` and is not being actively developed.

**Without an API key** the last stage falls back to a canned suggestion,
tagged `source: "fallback"` in `suggestions.json` so any frontend consuming it
can label the distinction honestly. The demo still runs end to end on bad
conference wifi; it just doesn't pretend the fallback came from the model.

---

## The pipeline

Four stages. Only the last one is an LLM.

| # | Stage | Script | Produces |
|---|-------|--------|----------|
| 1 | **Ingest** | `generate_mock_data.py` | `calendar.json`, `biometrics.csv` |
| 2 | **Score** | `analyze_stress.py` | sustained HRV depressions vs. a baseline |
| 3 | **Context** | `analyze_stress.py` | `detected_episodes.json` — meetings, back-to-back flag, next event |
| 4 | **Act** | `generate_suggestion.py` | `suggestions.json` — the LLM-written next step |

### 1 · Ingest

A single workday: 8 meetings, and per-minute HR/HRV from 09:00 to 17:00.

The stress episode is **scripted, not randomised**. HRV declines steadily across
a run of back-to-back meetings (13:00–15:00, no recovery gap) and recovers once
the run ends. Randomised noise would mean detection fires on some demo runs and
not others; a scripted signal makes the pipeline provable every time.

### 2 · Score

HRV is compared against a **baseline**, and a window only counts as an episode
if HRV stays below **80% of baseline for at least 20 consecutive minutes**. The
persistence requirement is what separates "a stressful moment" from "a sustained
load" — a single startling Slack message shouldn't trigger a scheduling
suggestion.

The baseline here is the **first hour of the day**. WHOOP's real Stress Monitor
uses a 14-day trailing baseline; for a single simulated day, first-hour is the
honest stand-in and it's a one-line change to swap in a real trailing window.

### 3 · Context

Each detected window is joined against the calendar: which meetings overlap it,
what kinds they are, whether they ran back-to-back, and what's scheduled next.
This is what turns "HRV is low" into "HRV is low **because of this specific run
of meetings**, and here is the gap you have coming up."

### 4 · Act

The structured episode goes to Gemini (`gemini-3-flash-preview`, with
`gemini-3.1-flash-lite` as a rate-limit fallback — both free tier via Google AI
Studio), which returns one specific suggestion. See
[Design decisions](#design-decisions-worth-knowing) for what the model does and
doesn't get to see.

---

## Why this scope

We researched the space before building, and deliberately scoped **away** from
the parts that already exist.

- **Real-time stress scoring from HRV is not novel.** WHOOP's Stress Monitor
  already computes it against a 14-day baseline. We reimplement a simplified
  version because the demo needs a signal to reason about — not because that
  part is the contribution.
- **Calendar overlay is a stated future direction, not a shipped feature.**
  WHOOP has described it; it isn't in the product.
- **Aggregation already has players.** Vora and ChronoCal pull multiple
  wearables and calendars into one view.

So the differentiation is narrow and specific, and it's the fourth stage:
**turning a detected stress pattern into a concrete next step tied to the actual
meeting context** — not another chart, and not generic wellness advice.

---

## What's real and what isn't

We'd rather be precise about this than oversell it.

| | |
|---|---|
| **Simulated** | The biometrics. The calendar. There is no wearable and no HealthKit/Google Calendar integration in this build. |
| **Real** | The detection logic, the calendar-context join, and the Gemini call. Those run on the mock data exactly as they would on real data. |
| **Claimed** | That the pipeline is shaped to accept a real HR/HRV feed — an Apple Watch, a WHOOP strap — in place of `biometrics.csv`. |
| **Not claimed** | That AirPods read biometrics. We looked; we couldn't verify it, so we don't say it. |

Swapping in real data means replacing stage 1 with a HealthKit / WHOOP API
reader that emits the same two files. Stages 2–4 don't change.

---

## Design decisions worth knowing

**The LLM never sees the raw time series.** It receives only the structured
episode summary — duration, which meetings, back-to-back flag, next event.
Feeding it 481 rows of per-minute HR/HRV would be slow, expensive, and would
mostly get the numbers paraphrased back. The model's job is the last mile, not
the maths.

**Detection is deterministic Python, not an LLM call.** Thresholds and
persistence windows are code, so the same input always produces the same
episode. That's what makes the demo reliable and the logic auditable.

**Suggestions must be actionable by one person alone.** The prompt forbids
anything that requires someone else's calendar to move. Multi-person
rescheduling is a genuinely hard constraint-satisfaction problem and was scoped
out on purpose — "move your own next meeting" is something you can act on the
second you read it.

**The dashboard is two stacked panels, not one dual-axis chart.** HRV and heart
rate have different units and different ranges; overlaying them on two y-scales
would invent a visual correlation the data doesn't contain. Shared time axis,
separate plots.

---

## Files

```
/pipeline/
  generate_mock_data.py    stage 1 — writes /data/calendar.json + /data/biometrics.csv
  analyze_stress.py        stages 2 & 3 — writes /data/detected_episodes.json
  generate_suggestion.py   stage 4 — writes /data/suggestions.json (the Gemini call)
  run_demo.py              runs all of the above in order
/data/                     everything the pipeline reads/writes — see PIPELINE_OVERVIEW.md
/web-dashboard-archive/
  index.html               the original dashboard — archived, not the active frontend
/docs/                     this file + PIPELINE_OVERVIEW.md
```

Every path in `/pipeline/` is resolved from the script's own file location, so
`run_demo.py` works whether you invoke it from the repo root, from inside
`/pipeline/`, or anywhere else.

Commit the generated `.json` / `.csv` files in `/data/` if you want any
consuming frontend to work immediately after a clone. Either way,
`run_demo.py` regenerates them — the mock data uses a fixed random seed, so
the output is identical every time.
