# LowCor health education sources

Verified September 19, 2026. This is general adult education, not personalized interpretation.

- [American Heart Association: All About Heart Rate](https://www.heart.org/en/health-topics/high-blood-pressure/the-facts-about-high-blood-pressure/all-about-heart-rate-pulse): typical adult resting range 60–100 BPM applies when calm and well, sitting or lying; fitness, medication, activity and emotions can affect heart rate. Workday sample average is not a resting measurement. Persistent changes warrant professional advice; concerning symptoms should not wait for app suggestions.
- [Apple HealthKit: heartRateVariabilitySDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn): the HealthKit SDNN metric is separate from ordinary heart-rate samples. LowCor imports it rather than deriving beat-to-beat variability from BPM values.
- [Cleveland Clinic: HRV](https://my.clevelandclinic.org/health/articles/21773-heart-rate-variability-hrv): HRV interpretation differs by person and age; sleep and other influences can affect it. The article's 24-hour clinical categories are intentionally NOT applied to brief wearable samples.
- [Shaffer & Ginsberg, 2017: HRV Metrics and Norms](https://www.frontiersin.org/journals/public-health/articles/10.3389/fpubh.2017.00258/full): recording duration, breathing, posture, signal quality and participant characteristics affect comparisons. No universal low/high SDNN thresholds are assigned in the app.
- [CDC: About Sleep](https://www.cdc.gov/sleep/about/index.html): adult recommendations are 7+ hours ages 18–60; 7–9 ages 61–64; 7–8 ages 65+. Duration alone does not establish sleep quality. LowCor's displayed Health records may be incomplete.
- [HSE: Work routine and breaks](https://www.hse.gov.uk/msd/dse/work-routine.htm): supports short, frequent breaks or changes of activity that allow movement, stretching or posture changes. Timing depends on work; the app's 15-minute duration is a product choice, not a clinical prescription.

Implementation safeguards: no stress diagnosis, no causal attribution to meetings, no assertion that higher HRV is always better, and no guarantee that a suggested pause will improve measurements. Missing values remain unknown. Human review is required before calendar writes.
