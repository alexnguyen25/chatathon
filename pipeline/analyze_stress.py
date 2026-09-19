"""
Stage 1 (this file, no LLM needed): detect sustained stress windows from HRV
data and attach calendar context — back_to_back run, meeting types involved,
what's coming up next. This is deterministic and cheap; don't waste LLM
calls on detection.

Stage 2 (see build_llm_prompt at the bottom): hand the DETECTED, STRUCTURED
episode to an LLM to turn into a specific suggestion. Never feed the raw
per-minute time series to the LLM — it's slow, expensive, and the model
will just paraphrase numbers instead of reasoning about the pattern.
"""

import csv
import json
from datetime import datetime, timedelta
from pathlib import Path

# Repo layout is /pipeline/ (this file) + /data/ (inputs/outputs) side by
# side — resolve from this file's location so the script works regardless
# of cwd.
DATA_DIR = Path(__file__).resolve().parent.parent / "data"

PERSISTENCE_MINUTES = 20   # HRV must stay depressed at least this long to count
HRV_DROP_THRESHOLD = 0.80  # flag when HRV falls below 80% of the day's baseline

def load_biometrics(path=DATA_DIR / "biometrics.csv"):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            rows.append({
                "timestamp": datetime.fromisoformat(r["timestamp"]),
                "hr": float(r["heart_rate"]),
                "hrv": float(r["hrv"]),
            })
    return rows

def load_calendar(path=DATA_DIR / "calendar.json"):
    with open(path) as f:
        events = json.load(f)
    for e in events:
        e["start"] = datetime.fromisoformat(e["start"])
        e["end"] = datetime.fromisoformat(e["end"])
    return events

def compute_baseline(rows, first_n_minutes=60):
    """Use the first hour of the day as the rolling baseline.
    (Real WHOOP data uses a 14-day trailing baseline — for a single mock day,
    first-hour-of-day is the honest stand-in and easy to explain to judges.)"""
    early = [r["hrv"] for r in rows[:first_n_minutes]]
    return sum(early) / len(early)

def find_stress_windows(rows, baseline):
    threshold = baseline * HRV_DROP_THRESHOLD
    windows = []
    current_start = None

    for i, r in enumerate(rows):
        below = r["hrv"] < threshold
        if below and current_start is None:
            current_start = r["timestamp"]
        elif not below and current_start is not None:
            duration = (r["timestamp"] - current_start).seconds / 60
            if duration >= PERSISTENCE_MINUTES:
                windows.append((current_start, r["timestamp"]))
            current_start = None

    # handle a window still open at end of day
    if current_start is not None:
        duration = (rows[-1]["timestamp"] - current_start).seconds / 60
        if duration >= PERSISTENCE_MINUTES:
            windows.append((current_start, rows[-1]["timestamp"]))

    return windows

def attach_calendar_context(window_start, window_end, calendar):
    overlapping = [e for e in calendar if e["start"] < window_end and e["end"] > window_start]
    next_event = next((e for e in calendar if e["start"] >= window_end), None)
    return {
        "meetings_in_window": [e["title"] for e in overlapping],
        "meeting_types": list({e["type"] for e in overlapping}),
        "any_back_to_back": any(e["back_to_back"] for e in overlapping),
        "next_event": next_event["title"] if next_event else None,
        "next_event_start": next_event["start"].isoformat() if next_event else None,
    }

def build_llm_prompt(episode):
    """This is the structured, low-token prompt to send to the LLM —
    features only, never the raw time series."""
    return f"""You are a workplace wellbeing assistant. A sustained stress episode
was detected from biometric data (not shown to you directly — only the summary below).

Episode summary:
- Duration: {episode['duration_minutes']} minutes
- Meetings during this window: {', '.join(episode['meetings_in_window'])}
- Meeting types involved: {', '.join(episode['meeting_types'])}
- Were these back-to-back with no break: {episode['any_back_to_back']}
- Next scheduled event: {episode['next_event']} at {episode['next_event_start']}

Write ONE specific, actionable suggestion (1-2 sentences) for this person.
Reference the actual meetings/pattern above, not generic wellness advice.
Do not suggest anything requiring other people's calendars to change."""

if __name__ == "__main__":
    rows = load_biometrics()
    calendar = load_calendar()
    baseline = compute_baseline(rows)
    windows = find_stress_windows(rows, baseline)

    print(f"Baseline HRV: {baseline:.1f}ms | Threshold: {baseline * HRV_DROP_THRESHOLD:.1f}ms")
    print(f"Found {len(windows)} sustained stress window(s)\n")

    episodes = []
    for start, end in windows:
        duration = round((end - start).seconds / 60)
        context = attach_calendar_context(start, end, calendar)
        episode = {"start": start.isoformat(), "end": end.isoformat(),
                   "duration_minutes": duration, **context}
        episodes.append(episode)

        print(f"Window: {start.strftime('%H:%M')}-{end.strftime('%H:%M')} ({duration} min)")
        print(f"  Meetings: {context['meetings_in_window']}")
        print(f"  Back-to-back: {context['any_back_to_back']}")
        print(f"  --- LLM prompt for this episode ---")
        print(build_llm_prompt(episode))
        print()

    with open(DATA_DIR / "detected_episodes.json", "w") as f:
        json.dump(episodes, f, indent=2)
