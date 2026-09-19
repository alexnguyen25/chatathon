# LowCor: on-device LLM analysis of calendar, HealthKit, and reflections

**Research date:** 2026-09-19  
**Scope:** iOS 26 SwiftUI design research for LowCor. This is product/platform guidance, not medical, legal, or regulatory advice.

## Decision

Use the Apple on-device `SystemLanguageModel` as an *optional reflection and planning* layer. It should receive only a compact, app-created daily snapshot: calendar facts that the person elected to include, voluntary HealthKit-derived **summaries** (not a stream of samples), and their own reflection. The model may turn those inputs into a clearly labeled, non-medical recap and a small choice of low-stakes planning prompts. It must not diagnose stress, illness, overtraining, or a health condition; score physiological risk; make medical claims; or control health-related actions.

Do not send HealthKit-derived data to a remote LLM in the MVP. An external LLM is a third-party disclosure: Apple requires prior express user consent, clear disclosure, and limits third-party sharing to a party providing a health or fitness service. An ordinary general-purpose model provider does not plainly satisfy that last condition, so explicit consent alone is not a safe product basis for this use. Keep the app on-device unless counsel and the provider's role, contract, security posture, consent flow, and privacy disclosures have been reviewed.

## What Apple’s framework supports

`FoundationModels` is a native Swift API for language understanding, structured output, and tool calling. Apple documents its on-device model as useful for summarization, entity extraction, text understanding/refinement, short dialog, and creative generation; those fit reflection and planning much better than physiological assessment. The current documentation identifies `SystemLanguageModel` as the on-device Apple Foundation Model and lists model versions for iOS 26.0–26.3 and iOS 26.4. Availability is not universal: it depends on an Apple-Intelligence-capable device and region, and the app must handle `.deviceNotEligible`, `.modelNotReady`, and Apple Intelligence being disabled. [Foundation Models overview][fm-overview] [SystemLanguageModel][system-model]

Use guided generation for an app-owned, restricted response type. `@Generable` turns a Swift type into a schema and constrained sampling prevents malformed output; it does **not** make content factually or clinically valid. Keep the schema small, constrain any recommendation to a curated enum, and require the model to cite only snapshot facts it received. For example, a response can contain: `observedFacts`, `reflectionSummary`, `planningPrompt`, `suggestedAction` (`.reviewAgenda`, `.protectFocusTime`, `.takeOptionalBreak`, `.none`), and `medicalAssessment: false`. [Guided generation][guided-generation]

Tool calling can be a privacy-preserving seam: Apple explicitly says a custom tool can integrate with HealthKit while using its existing privacy and security mechanisms. Prefer a deterministic `dailySnapshot` tool that returns already-minimized values—such as user-selected event count/time blocks, measurement duration, median heart rate, and an explicitly calculated change from a local baseline—rather than exposing a generic query tool or every raw sample. Tools can be used concurrently, but their definitions and outputs consume context, so Apple recommends only three to five tools and direct retrieval when the model does not need to choose what to fetch. [Tool calling][tool-calling] [Context guidance][context-guidance]

## Privacy and HealthKit boundary

HealthKit grants access by individual data type; the person may allow, limit, or deny reads. An app is deliberately not told which read type was denied, so empty data is not evidence of a normal measurement. HealthKit data is stored locally and encrypted when the device is locked. Purpose strings and a clear privacy policy are required. [Protecting HealthKit privacy][health-privacy]

Apple’s current HealthKit policy says an app may not disclose HealthKit information to a third party without the person’s express permission; even then, the third party may receive it only to provide a health or fitness service. The app must clearly disclose its use, and it may not use/sell this data for advertising, data brokers, or information resellers. Apple’s Developer Program License Agreement also applies the same restriction to health, motion, fitness, and journaling-suggestions information. [Protecting HealthKit privacy][health-privacy] [Developer Program License Agreement, §3.3(D)][adpla]

Apple says on-device Apple Intelligence processing can complete a task without data leaving the device. However, Apple Intelligence can use Private Cloud Compute for workloads that need more compute; PCC data is processed only to fulfill the request and is not retained or accessible to Apple. These are Apple's privacy assurances, not a reason to silently change LowCor’s on-device promise. The MVP should instantiate only the on-device `SystemLanguageModel`, avoid Private Cloud Compute and third-party `LanguageModel` providers, declare this precisely in product copy, and retain a deterministic non-LLM fallback. [Apple Intelligence & Privacy][ai-privacy] [Foundation Models overview][fm-overview]

## Recommended safe analysis contract

1. **Permission and minimization:** request Calendar and each HealthKit type independently at the moment the feature is used. Let the person choose which calendar information is included (for example, count/duration rather than event titles), and make health inclusion off by default.
2. **Deterministic health summaries first:** compute transparent, time-bounded descriptive facts locally (for example: sample availability, median/range, and comparison to an explicitly named personal baseline). Preserve source, time window, and missing-data state. Do not imply HRV is continuously available or comparable across sources.
3. **LLM as narrator, not assessor:** send only that small snapshot plus an optional free-text reflection to the on-device model. It can organize the person’s stated experience and offer a planning question; it must never infer a physiological state, causal story, diagnosis, or treatment.
4. **Bounded output and provenance:** generate a structured card with fact references, a `notEnoughData` option, and a fixed disclaimer. Render the underlying facts alongside it. Do not let free-form model output trigger notifications, calendar edits, workout changes, sharing, or escalation.
5. **Failure path:** when the model is unavailable, show the same local facts and reflection composer. Never degrade to a network model with the same data without a separately designed, explicit consent flow and policy review.

## Assessment of the current `LoadAnalyzer` concept

The current implementation labels a window “elevated load” when heart rate is at least 10 BPM above a baseline made from only the first two samples, HRV is at most 80% of that baseline, and the preceding hour has at least two meetings. That is a deterministic heuristic, but it is not a validated measurement of stress or physiological load. It has important risks:

- The two-sample baseline is unstable; fixed thresholds do not account for person-specific variation, sleep, illness, medication, activity, posture, sensor source/quality, or time of day.
- Calendar density is contextual metadata, not a physiological cause. Joining it to heart rate/HRV can invite an unsupported causal claim (for example, “meetings caused stress”).
- Missing, denied, delayed, or source-mixed HealthKit data can be mistaken for an observed state. HealthKit’s permission model deliberately makes denied reads indistinguishable from absent data to the app. [Protecting HealthKit privacy][health-privacy]
- An LLM asked to explain this label will add plausible language, not clinical validation. Structured output reduces malformed responses, not hallucination or medical-risk errors. [Guided generation][guided-generation]
- Apple reviews more closely apps that could diagnose or treat patients, and requires health-measurement accuracy claims to disclose data and methodology that can be validated. “Elevated load,” “stress detected,” and similar UI wording would move LowCor toward that risk. [App Review Guidelines 1.4.1][app-review]

For the prototype, retire the label from user-facing analysis. If the code is kept for experimentation, rename its output to a neutral observation such as `candidateCorrelationWindow`, keep it behind a developer-only flag, do not show it as a health result, and do not pass it to an LLM as ground truth. A future user-facing metric needs a separately specified purpose, evidence, validation plan, calibration policy, and review of medical-device and privacy obligations.

## Sources (all primary Apple sources)

[fm-overview]: https://developer.apple.com/documentation/foundationmodels/
[system-model]: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
[guided-generation]: https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
[tool-calling]: https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling
[context-guidance]: https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
[health-privacy]: https://developer.apple.com/documentation/healthkit/protecting-user-privacy
[adpla]: https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
[ai-privacy]: https://www.apple.com/legal/privacy/data/en/intelligence-engine/
[app-review]: https://developer.apple.com/app-store/review/guidelines/

