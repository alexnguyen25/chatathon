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

DAY_START = datetime(2026, 9, 19, 9, 0)
DAY_END = datetime(2026, 9, 19, 17, 0)

# ---- 1. Calendar ----
# back_to_back = True if it starts within 5 min of the previous meeting ending
CALENDAR_RAW = [
    ("09:00", "09:30", "Standup", "team"),
    # 30-min gap here (recovery time)
    ("10:00", "11:00", "Design Review", "high_focus"),
    ("11:00", "12:00", "Client Call", "high_stakes"),
    # lunch gap
    ("13:00", "13:30", "1:1 with Manager", "one_on_one"),
    ("13:30", "14:30", "Sprint Planning", "high_focus"),
    ("14:30", "15:00", "Cross-team Sync", "team"),
    # 15-min gap (recovery starts here)
    ("15:15", "16:15", "Deep Work Block", "focus_time"),
    ("16:15", "16:45", "All-Hands", "team"),
]

def parse(t):
    h, m = map(int, t.split(":"))
    return datetime(2026, 9, 19, h, m)

calendar = []
prev_end = None
for start_s, end_s, title, mtype in CALENDAR_RAW:
    start, end = parse(start_s), parse(end_s)
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
# Baseline HR ~68bpm resting, HRV ~65ms (arbitrary but realistic-looking units).
# The scripted stress run is 13:00-15:00 (three back-to-back meetings, no gap):
#   HRV declines ~2ms per 10 min of sustained back-to-back load, HR climbs slightly.
# Outside that window, values drift gently around baseline with small noise.

STRESS_WINDOW_START = parse("13:00")
STRESS_WINDOW_END = parse("15:00")
BASELINE_HR = 68
BASELINE_HRV = 65

rows = []
t = DAY_START
minutes_into_stress = 0

while t <= DAY_END:
    in_stress_window = STRESS_WINDOW_START <= t <= STRESS_WINDOW_END

    if in_stress_window:
        minutes_into_stress += 1
        # steady decline, caps out so it doesn't go unrealistic
        hrv_drop = min(minutes_into_stress * 0.18, 22)
        hr_rise = min(minutes_into_stress * 0.09, 11)
    else:
        # recovery: HRV eases back toward baseline once out of the window
        if minutes_into_stress > 0 and t > STRESS_WINDOW_END:
            minutes_since_recovery = (t - STRESS_WINDOW_END).seconds // 60
            hrv_drop = max(22 - minutes_since_recovery * 1.6, 0)
            hr_rise = max(11 - minutes_since_recovery * 0.8, 0)
        else:
            hrv_drop = 0
            hr_rise = 0

    hr = round(BASELINE_HR + hr_rise + random.uniform(-1.5, 1.5), 1)
    hrv = round(BASELINE_HRV - hrv_drop + random.uniform(-2, 2), 1)

    rows.append({"timestamp": t.isoformat(), "heart_rate": hr, "hrv": hrv})
    t += timedelta(minutes=1)

with open(DATA_DIR / "biometrics.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["timestamp", "heart_rate", "hrv"])
    writer.writeheader()
    writer.writerows(rows)

print(f"Generated {len(calendar)} calendar events -> calendar.json")
print(f"Generated {len(rows)} biometric readings -> biometrics.csv")
print("Scripted stress episode: 13:00-15:00 (Sprint Planning + Cross-team Sync run)")
