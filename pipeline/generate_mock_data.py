"""
Generates a realistic single-day mock dataset for the WHOOP hackathon demo:
  - calendar.json: a workday's meeting blocks
  - biometrics.csv: per-minute HR/HRV readings, 9:00am-5:00pm

The stress episode is SCRIPTED, not random: HRV declines steadily across a
run of back-to-back meetings (1:00-3:00pm) with no recovery gap, then
recovers once the run ends. This gives the demo a clean, provable signal
instead of noisy randomness that may or may not trigger detection.
"""

import json
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

random.seed(42)  # reproducible mock data — same run every time you demo

# Repo layout is /pipeline/ (this file) + /data/ (outputs) side by side —
# resolve from this file's location so the script works regardless of cwd.
DATA_DIR = Path(__file__).resolve().parent.parent / "data"

DAY_START = datetime(2026, 9, 21, 9, 0)
DAY_END = datetime(2026, 9, 21, 17, 0)

# ---- 1. Calendar ----
# back_to_back = True if it starts within 5 min of the previous meeting ending
CALENDAR_RAW = [
    ("09:00", "10:00", "Planning", "team"),
    ("10:00", "11:00", "Focus", "focus_time"),
    ("11:00", "12:00", "Design Review", "high_focus"),
    # The open 12:00-12:30 slot is the safe, user-controlled recovery opportunity.
    ("12:30", "13:00", "Lunch", "personal"),
    ("13:00", "15:00", "Deep Work", "focus_time"),
    ("15:00", "16:00", "Team Sync", "team"),
    ("16:00", "17:00", "Wrap-up", "team"),
]

def parse_demo_time(t):
    h, m = map(int, t.split(":"))
    return datetime(2026, 9, 21, h, m)

calendar = []
prev_end = None
for start_s, end_s, title, mtype in CALENDAR_RAW:
    start, end = parse_demo_time(start_s), parse_demo_time(end_s)
    back_to_back = prev_end is not None and (start - prev_end) <= timedelta(minutes=5)
    calendar.append({
        "title": title,
        "type": mtype,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "back_to_back": back_to_back,
    })
    prev_end = end

with open(DATA_DIR / "calendar.json", "w") as f:
    json.dump(calendar, f, indent=2)

# ---- 2. Biometrics ----
# Baseline HR ~70bpm and HRV ~65ms. The synthetic showcase peaks during
# Design Review (11:00-12:00): HR rises into the low 90s while HRV falls into
# the low 40s, then both recover during the open 12:00-12:30 calendar slot.
# It is designed to be visually legible, not to simulate or diagnose stress.

STRESS_WINDOW_START = parse_demo_time("11:00")
STRESS_WINDOW_END = parse_demo_time("12:00")
BASELINE_HR = 70
BASELINE_HRV = 65

rows = []
t = DAY_START
minutes_into_stress = 0

while t <= DAY_END:
    in_stress_window = STRESS_WINDOW_START <= t <= STRESS_WINDOW_END

    if in_stress_window:
        minutes_into_stress += 1
        # steady decline, caps out so it doesn't go unrealistic
        hrv_drop = min(minutes_into_stress * 0.38, 23)
        hr_rise = min(minutes_into_stress * 0.36, 22)
    else:
        # recovery: HRV eases back toward baseline once out of the window
        if minutes_into_stress > 0 and t > STRESS_WINDOW_END:
            minutes_since_recovery = (t - STRESS_WINDOW_END).seconds // 60
            hrv_drop = max(23 - minutes_since_recovery * 1.3, 0)
            hr_rise = max(22 - minutes_since_recovery * 1.1, 0)
        else:
            hrv_drop = 0
            hr_rise = 0

    hr = round(BASELINE_HR + hr_rise + random.uniform(-1.5, 1.5), 1)
    hrv = round(BASELINE_HRV - hrv_drop + random.uniform(-2, 2), 1)

    rows.append({"timestamp": t.isoformat(), "heart_rate": hr, "hrv": hrv})
    t += timedelta(minutes=1)

with open(DATA_DIR / "biometrics.csv", "w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=["timestamp", "heart_rate", "hrv"],
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(rows)

print(f"Generated {len(calendar)} calendar events -> calendar.json")
print(f"Generated {len(rows)} biometric readings -> biometrics.csv")
print("Synthetic showcase signal: 11:00-12:00 (Design Review), then recovery in the open 12:00-12:30 slot")
