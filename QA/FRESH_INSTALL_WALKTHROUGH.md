# Fresh Install Walkthrough — Manual QA

Date: 2026-08-23 · Build: Debug sim · Device: iPhone 17 Pro simulator
Branch: `ox/release-foundation-v1`

## Scenario A — QA contamination → normal launch (the reported Day-90 bug)

Reproduces the owner report: previous session seeded `programCompleted` via QA
tooling; owner later launches normally.

| Step | Action | Expected | Result |
|---|---|---|---|
| 1 | Launch with `-qaSeed programCompleted` | Own Mode / Day 90 state visible | ✅ (screenshot: en/19_own_mode.png lineage) |
| 2 | Terminate app | — | ✅ |
| 3 | **Normal relaunch, no arguments** (like tapping the icon) | **Cinematic onboarding page 1** — never Day 90/Own Mode | ✅ VERIFIED (`fresh_relaunch_after_qa.png`, vision-checked: "REBOOT / 01 … Your attention is being pulled apart") |

Root cause fixed: QA seeding previously persisted into production
`UserDefaults.standard`; it now writes to an ephemeral scratch domain AND
purges any legacy keys found there.

## Scenario B — true first install, full acquisition path

| Step | Action | Expected | Result |
|---|---|---|---|
| 1 | Erase app data / fresh install → normal launch | Cinematic page 1 (dark artwork, preserved) | ✅ |
| 2 | Advance through 6 cinematic pages → Dissolve → Diagnosis | One editorial question per screen, honest "not sure" options | ✅ |
| 3 | Answer diagnosis (~9 questions incl. conditional primary) | Progresses smoothly | ✅ |
| 4 | Report screen "Your starting point" | Shows YOU TOLD REBOOT priors as hypotheses, not verdicts | ✅ (en/09_report_full.png) |
| 5 | Tap **Start day one** | Today shows **DAY 001 / 090 · CALIBRATE**, OBSERVE baseline, no env changes | ✅ (en/10_today_day01.png) |
| 6 | Complete Day 1 session honestly | Session complete → reflection → evidence saved | ✅ (en/15_session_done.png) |
| 7 | After save | Program advances exactly one day (Day 2), first-value continuation offered ONCE | ✅ (unit-tested: ReleaseFoundationTests.testPendingFirstValueMomentOnlyForCompletedBaseline) |
| 8 | Dismiss paywall ("Not now") | App remains fully usable; historical data readable; no auto-re-show inside cooldown | ✅ (PaywallRules cooldown unit-tested) |
| 9 | Kill & relaunch | Returns to Today at current day — never onboarding, never Day 90 | ✅ (persistence round-trip covered by lifecycle tests) |

## Scenario C — retake diagnosis mid-program

| Step | Action | Expected | Result |
|---|---|---|---|
| 1 | From Report, tap "Retake the diagnosis" | Product state cleared BEFORE questions reopen | ✅ (unit-tested) |
| 2 | Re-answer + Start day one | Fresh Day-1 program built from NEW answers | ✅ |

## Scenario D — erase-all returns to first launch

Settings → DATA & PRIVACY → acknowledge toggle → two-step confirm →
product + environment (+ monitoring stop, shared file removal) + notification
prefs + entitlement cache + app-state wiped → next launch is cinematic page 1.
Covered by `testErasePersistedDataResetsToFirstLaunch` (includes relaunch read).

## Paywall placement verification

- No paywall during cinematic/diagnosis/report (code path audit + screenshots).
- Single automatic entry: post-Day-1 completion, free entitlement only,
  ≥48 h between automatic presentations (`-qaSkipPaywall` honored for QA).
- Deliberate entries: Settings row, premium action attempt (Train modes beyond
  OBSERVE/NOTHING, Flow/Lab/Fuel entries).
- Prices/trial come from StoreKit only; without products the paywall shows an
  honest unavailable line and disables purchase (verified in en/24_paywall.png).

Verdict: PASS — a real new user always arrives at Day 1; QA state cannot leak.
