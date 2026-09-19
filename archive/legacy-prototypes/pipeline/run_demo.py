"""
Runs the whole pipeline end to end, in order. This is the one command to run
before demoing. Can be invoked from anywhere (e.g. `python3 pipeline/run_demo.py`
from the repo root, or `python3 run_demo.py` from inside /pipeline/) — every
path below is resolved from this file's own location, not the caller's cwd.

  ingest  -> generate_mock_data.py    /data/calendar.json, /data/biometrics.csv
  score   -> analyze_stress.py        /data/detected_episodes.json
  context -> analyze_stress.py        (same pass — calendar attached to each episode)
  act     -> generate_suggestion.py   /data/suggestions.json
"""

import subprocess
import sys
from pathlib import Path

PIPELINE_DIR = Path(__file__).resolve().parent

STAGES = [
    ("1 · ingest            ", "generate_mock_data.py"),
    ("2/3 · score + context ", "analyze_stress.py"),
    ("4 · act               ", "generate_suggestion.py"),
]

for label, script in STAGES:
    print(f"\n=== {label} ({script}) " + "=" * 24)
    result = subprocess.run([sys.executable, str(PIPELINE_DIR / script)], check=False)
    if result.returncode != 0:
        sys.exit(f"\n{script} failed — stopping.")

print("\n" + "=" * 60)
print("Done. All four /data/ files are up to date.")
print("The active frontend (iOS-style UI) is being built separately — point it at /data/.")
print("(The old HTML dashboard in /web-dashboard-archive/ still fetches its data files")
print(" by relative path, which now points at the wrong folder — untouched, since")
print(" frontend work here is out of scope; fix its fetch paths before reviving it.)")
