# App Review Notes — REBOOT

## What REBOOT is
REBOOT is a 90-day attention-training program. It prescribes one short behavioral practice per day (e.g., staying with a single task, returning after a distraction, recalling what you just read), learns from the user's own session reflections, and after 90 days synthesizes an "Attention Operating Manual" from that evidence. It is **not a medical product**: it does not diagnose, treat, or prevent any condition, and it makes no neurological claims.

## Why Screen Time / Family Controls are used
REBOOT optionally helps users reduce digital distraction during practice sessions:
- With **Family Controls authorization**, the user selects apps to shield. Selections are stored as opaque tokens; REBOOT cannot decode them into app names and never logs or transmits them.
- During an active practice session, REBOOT may apply a **Managed Settings shield** over those selected apps; it is removed when the session ends.
- Optional **DeviceActivity** monitoring powers user-approved "Focus Windows" (weekly schedules) and a single daily threshold event. The monitor extension writes only our own event names + timestamps into the shared app group — no app usage data leaves the device.
Nothing is monitored outside these explicit, user-configured features. No foreground surveillance exists.

## How to reach Screen Time features
Profile tab → Environment section → connect Screen Time (system permission sheet appears) → set up Focus Windows or session protection. All permission prompts are contextual to this flow.

## Subscription
- Free: full onboarding, diagnosis, initial profile, **Day 1 baseline session with first insight**.
- Premium: Days 2–90 of the program, Flow Lab, Personal Lab, advanced environment automation, Operating Manual.
- Paywall appears once after Day 1 completes (first genuine insight), then only via deliberate actions (premium feature attempts or Settings). Restore Purchases is on the paywall and in Settings.
- Prices/trial come directly from StoreKit products (`reboot.monthly`, `reboot.yearly`).

## How to test the core path (5 minutes)
1. Fresh install → complete cinematic onboarding and the ~9 diagnosis questions → "Your starting point" report appears → tap **Start day one**.
2. Today shows DAY 001 · CALIBRATE with an OBSERVE baseline session (~15 min, can be ended early via the timer's end control for review speed).
3. Complete the reflection → the app shows what was learned → the premium continuation offer appears (dismissable).
4. Without purchasing, Today stays usable; historical data remains accessible.
5. To test purchase flows, attach a StoreKit configuration file or use sandbox testers.

## Non-medical confirmation
All copy avoids diagnosis/treatment language. The paywall footer and Terms state the non-medical nature explicitly. Category recommendation: Lifestyle or Productivity — not Medical.
