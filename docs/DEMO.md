# PulsePlan demo

Run the **PulsePlan** scheme from `ios/PulsePlan.xcodeproj` on iOS 26 or newer. The app starts with **Demo day · 11:55 AM**. If demo mode was turned off earlier, open **Connections** and enable **Explore a demo day**.

1. Show **Your day**: 15 fictional events, a packed morning, and a 12:00–12:30 opening before lunch.
2. Show **Health**: fictional heart-rate readings, including gaps and an exaggerated sustained rise. These are sample observations, not evidence that meetings caused stress.
3. On **Today**, tap **Analyze my signals**. Swift computes the observations and applies the heart-pattern rule. Only a flagged pattern permits a suggestion; calendar availability determines where the pause fits.
4. Read the source label. Available Apple Foundation Models inference chooses a constrained calm pause on-device. Otherwise, the app identifies its fallback; the demo remains usable without a cloud API key.
5. Tap **Review break**. Confirm the proposed **12:00–12:15** “Private reset” and **Demo calendar · this app only** destination.
6. Tap **Add to demo day**, then **See it in my day**. The break appears in the fictional schedule; no real calendar record was created.
7. Use **Reset** in the demo banner to restore the scenario.

A concise presentation line: “PulsePlan checks a sustained heart-rate pattern, shows the observations behind it, and helps you review an optional pause that fits your day. Facts and scheduling are computed locally; on-device AI chooses the kind of calm pause.”

Keep the distinction explicit: the readings are fictional, the rule is experimental and nonmedical, and the AI cannot diagnose stress. Optional real Health and Calendar connections require permission; real calendar saves require confirmation. Live sensor collection is a separate workout-based feature and requires hardware testing.
