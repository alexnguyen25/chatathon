"""
Stage 3 (act): turn each DETECTED episode into one concrete, actionable
suggestion using the Gemini API.

The model only ever sees the structured episode summary built by
analyze_stress.build_llm_prompt() — duration, which meetings, back-to-back
flag, next event. It never sees the per-minute HR/HRV series. Detection
stays deterministic Python; the LLM's only job is the last mile: pattern ->
specific next step.

Writes suggestions.json — the episodes each with a `suggestion` attached, plus
the baseline/threshold the detector used. That file is the frontend's only
input for the "score" and "act" stages, so the dashboard never has to
re-implement any of the detection maths in JavaScript.

If there's no API key or the call fails, we fall back to a canned suggestion
and tag it `source: "fallback"` so the demo still runs on a bad conference
wifi — the UI labels it rather than passing it off as model output.
"""

import json
import os
import sys

from analyze_stress import (
    DATA_DIR,
    HRV_DROP_THRESHOLD,
    build_llm_prompt,
    compute_baseline,
    load_biometrics,
)

# "gemini-3-flash" (no suffix) isn't a real model ID for this API key/version —
# ListModels shows "gemini-3-flash-preview" as the closest match. Confirm
# before the demo whether a stable "gemini-3-flash" lands later.
MODEL = "gemini-3-flash-preview"
# Free-tier fallback if the primary model's rate limit gets hit mid-demo.
MODEL_FALLBACK = "gemini-3.1-flash-lite"
# The app demo is local by default. A remote model can only be enabled
# deliberately for synthetic fixtures with PULSEPLAN_ENABLE_REMOTE_SUGGESTIONS=1.
USE_REMOTE_SUGGESTIONS = os.environ.get("PULSEPLAN_ENABLE_REMOTE_SUGGESTIONS") == "1"

# Used only when the API is unreachable. Deliberately written to the same
# spec as the prompt (specific, references the actual pattern, actionable
# solo) so a fallback demo still shows the right *kind* of output.
FALLBACK_SUGGESTION = (
    "Your readings changed during Design Review, and you have a clear 12:00-12:30 "
    "gap before Lunch. Consider protecting 12:00-12:15 as a private reset before "
    "your afternoon work."
)


def load_episodes(path=DATA_DIR / "detected_episodes.json"):
    with open(path) as f:
        return json.load(f)


def generate_suggestion(episode, client):
    """One API call per detected episode. Returns the suggestion text.

    Tries MODEL first, falls back to MODEL_FALLBACK on a rate-limit-shaped
    error (free tier is ~10 req/min) before giving up to the caller's
    canned-text fallback.
    """
    from google.genai import errors as genai_errors

    prompt = build_llm_prompt(episode)

    last_error = None
    for model in (MODEL, MODEL_FALLBACK):
        try:
            response = client.models.generate_content(model=model, contents=prompt)
            text = (response.text or "").strip()
            if not text:
                raise RuntimeError(f"{model} returned no text")
            return text, model
        except genai_errors.ClientError as e:
            last_error = e
            if getattr(e, "code", None) != 429:
                raise  # not a rate limit — don't mask a real error by retrying
    raise last_error


def write_output(baseline, episodes):
    payload = {
        "baseline_hrv": round(baseline, 1),
        "threshold_hrv": round(baseline * HRV_DROP_THRESHOLD, 1),
        "threshold_pct": HRV_DROP_THRESHOLD,
        "is_synthetic": True,
        "model": next((episode["source"] for episode in episodes if episode["source"] != "fallback"), "fallback"),
        "episodes": episodes,
    }
    with open(DATA_DIR / "suggestions.json", "w") as f:
        json.dump(payload, f, indent=2)


def main():
    baseline = compute_baseline(load_biometrics())
    episodes = load_episodes()
    if not episodes:
        print("No episodes in detected_episodes.json — run analyze_stress.py first.")
        write_output(baseline, [])
        return

    client = None
    setup_error = None
    api_key = os.environ.get("GEMINI_API_KEY")
    if not USE_REMOTE_SUGGESTIONS:
        setup_error = "remote suggestions are disabled for the local demo"
    elif not api_key:
        setup_error = "GEMINI_API_KEY is not set"
    else:
        try:
            from google import genai

            client = genai.Client(api_key=api_key)
        except Exception as e:
            setup_error = e

    results = []
    for episode in episodes:
        if client is None:
            text, source = FALLBACK_SUGGESTION, "fallback"
            print(f"  ! no Gemini client ({setup_error}) — using fallback text", file=sys.stderr)
        else:
            try:
                text, source = generate_suggestion(episode, client)
            except Exception as e:
                text, source = FALLBACK_SUGGESTION, "fallback"
                print(f"  ! Gemini call failed ({e}) — using fallback text", file=sys.stderr)

        results.append({
            **episode,
            "suggestion": text,
            "source": source,
            "is_synthetic": True,
            "proposed_break": {
                "title": "Private reset",
                "start": "2026-09-21T12:00:00",
                "end": "2026-09-21T12:15:00",
                "reason": "Open time after Design Review and before Lunch",
            },
        })

        window = f"{episode['start'][11:16]}-{episode['end'][11:16]}"
        print(f"Episode {window} ({episode['duration_minutes']} min) [{source}]")
        print(f"  {text}\n")

    write_output(baseline, results)
    print(f"Wrote {len(results)} suggestion(s) -> suggestions.json")


if __name__ == "__main__":
    main()
