# Health-driven MVP check-in

The app no longer recommends a break because a calendar gap exists. It first checks recorded heart-rate patterns; only a flagged pattern invokes calendar placement and the on-device AI pause selection. A positive observation is still displayed when no slot is available. Missing data or an unflagged pattern produces no scheduled suggestion, and neither result rules out stress or a health issue.

The heuristic is deliberately labeled **unvalidated** in the app's Info screen. In the last 30 minutes it requires at least 4 samples over 15 minutes, no gap above 10 minutes, and a latest reading within 10 minutes. An earlier comparison requires at least 4 samples over 15 minutes. Recent average and at least 80% of recent values must be at least 20 BPM and 25% above the earlier sample mean. These are prototype product settings, not clinical thresholds.

Demo data is fictional: recent 30-minute sample mean 145.1 BPM versus 95.4 earlier that day, latest 148 and peak 150. The separate calm 09:00–10:25 period averages 70.8 BPM; the app does not mislabel that narrower period as the full earlier comparison.

The explanation is computed from actual sample statistics. AI selects a quiet or screen-free pause, cannot invent medical facts, and cannot override the health-pattern gate. HRV, sleep and calendar load are context, not proof of stress. Readings during activity are not treated as resting values.

If a rate is unexpectedly high while resting, the UI advises medical advice rather than waiting for a scheduled pause. Existing Info guidance covers concerning symptoms. Heart rate can reflect many factors; see [American Heart Association](https://www.heart.org/en/health-topics/high-blood-pressure/the-facts-about-high-blood-pressure/all-about-heart-rate-pulse).

Verified: signed iPhone build, installation/launch, 11 executable signal checks (including stable/decreasing/isolated spike/missing/stale/gaps/future/duplicate-timestamp cases). No real Health or calendar records were written while testing.
