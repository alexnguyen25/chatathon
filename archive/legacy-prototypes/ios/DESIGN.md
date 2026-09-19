# Visual direction — LowCor

Derived from the five supplied mockups, not invented. This records the system
those screens imply so new work stays consistent with them.

## Palette

Warm paper, forest green, one reserved accent.

| Role | Light | Dark |
| --- | --- | --- |
| Canvas (paper) | `#F3F2EE` | `#14150F` |
| Surface (white cards) | `#FFFFFF` | `#1D1F1B` |
| Sage (info blocks, calendar) | `#E3EAE1` | `#232D25` |
| Sage deep (added/selected) | `#D3DED1` | `#2C382E` |
| Hairline | `#E4E3DD` | `#2D302A` |
| Ink | `#14160F` | `#F1F2EC` |
| Ink secondary | `#6B6F66` | `#A7ADA2` |
| Ink tertiary | `#92988C` | `#7B8178` |
| **Green** (actions, active tab) | `#2C5F4A` | `#4E9C7B` |
| **Terracotta** (signal only) | `#C0604A` | `#D98168` |

**The one rule that holds this together: terracotta is the biometric signal
and nothing else.** The heart glyph, the heart-rate line and its dots, and the
marker on the calendar entry the readings changed during. It never appears on a
button, a heading, or a success state. Green carries all action.

That restraint is what keeps a warm palette from reading as the generic
cream-and-clay look — the moment terracotta starts showing up on chrome, it
becomes exactly that. Dark mode bottoms out at `#14150F`, never `#000000`.

## Type

System font, heavy display weights, tracking that changes with size.

| Role | Style | Weight | Tracking |
| --- | --- | --- | --- |
| Display title | `.largeTitle` | bold | `-1.0` |
| Subtitle | `.title3` | regular | `0` |
| Section heading | `.title2` | bold | `-0.4` |
| Row title | `.subheadline` | semibold | `0` |
| Row body | `.subheadline` | regular | `0` |
| BPM readout | 92pt | bold | `0`, **monospaced digits** |

Every number that can change is monospaced. The live BPM readout updates every
two seconds; proportional digits would make it jitter, and it uses
`.contentTransition(.numericText())` so the value cross-fades in place rather
than sliding.

## Geometry

| Element | Radius |
| --- | --- |
| Cards | 14 |
| Calendar blocks, inline blocks | 10 |
| Buttons | 12 |
| Success tile | 18 |
| Pills | capsule |

No shadows anywhere. Separation is carried by the paper/white contrast and by
1px hairlines. White cards read as raised because the canvas is warm, not
because anything is blurred behind them.

## Screens

```
Live  ──────────────────────  Example day
                                   │
                              Your day  ──► A little room to reset
                                                    │
                                              Add a break  ──►  Break added
```

Tab bar is persistent. The break flow is a `NavigationStack` path inside the
Example day tab, so the tab bar never disappears mid-flow.

## The day timeline

Time, calendar, and heart rate share **one** vertical axis driven by a single
`y(forMinute:)`. They are not three charts aligned by eye — a calendar entry
and the readings beside it have to line up exactly, and independently scaled
views cannot promise that.

Time runs top to bottom, 9 AM to 5 PM. Heart rate is plotted horizontally
against that vertical time axis, one point per 30 minutes. Minute-level would
be a smear at 132pt wide.

The empty 12:00–12:30 slot is drawn as a dashed green outline and disappears
once a break is added to it.

## Motion

| Interaction | Spring |
| --- | --- |
| Default, card resize, success tile | `duration 0.4, bounce 0` |
| Post-gesture settle | `duration 0.35, bounce 0.2` |
| Button press | `duration 0.22, bounce 0`, scale `0.98` |

Press feedback lands on touch-down, not release. Reduced motion swaps springs
for a 0.18s cross-fade and drops the scale effects — a gentler equivalent, not
an absence of feedback.

The explanation loads as three breathing skeleton lines with a Cancel beside
them, never a modal spinner: a spinner says "blocked", and this is
interruptible by design.

## Copy rules baked into the UI

- Every screen that shows synthetic data says so — the "Sample data" pill on
  the day, the label on the add and confirm screens.
- "Your real calendar has not changed" appears on the confirmation, because
  the screen otherwise looks exactly like a real calendar write.
- The heart-rate reason is phrased as two ranges, never one averaged number.
  "84–96 during the last hour" is an observation about a window; "your heart
  rate is 90" is a claim about a person.
- The disclaimer — "a suggested pause, not a stress diagnosis" — sits in the
  main flow, not in fine print.
