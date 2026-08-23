# REBOOT — Full App Screen Map (canonical UI inventory)

Route/state inventory for every app-owned page. `entry` = how a user reaches it.
Premium column: F = free access, P = premium, C = conditional.

| ID | Screen | Entry | Required state | Prem | Notes |
|----|--------|-------|----------------|------|-------|
| ONB-1..6 | Cinematic onboarding pages 1–6 | First launch / DebugNav | `AppState.phase = .cinematic` | F | 6 fixed artworks, preserved |
| DSV-1 | Dissolve interstitial | End of cinematic | `.dissolve` | F | |
| DX-Q1..9 | Diagnosis questions | After dissolve | `.diagnosis`, step 0..n | F | incl. conditional primary question |
| DX-RPT | Your starting point report | Last diagnosis answer | `.report` | F | Start day one → canonical program init |
| TODAY-Dx | Today (per phase) | Tab root | `product.phase = .today`, tab .today | C | Day 1 free; Day 2+ premium gate on start |
| TODAY-ENV | Before-you-start environment block | Guidance-driven | envAction present | C | |
| TODAY-FUEL | Fuel prompt card | Guidance-driven | fuelPrompt present | P | |
| TODAY-OWN | Own Mode card | Completed program | status == completed | — | suggestion / nothing-needed states |
| TRN | Train tab | Tab | tab .train | C | OBSERVE/NOTHING free, others premium-gated in UI |
| SES-PREP | Session preparation | Start any session | `.preparing(request)` | C | |
| SES-RUN | Active session | Begin | `.running` | C | timer, switch/return capture |
| SES-DONE-Q | Session reflection questions | Finish | `.done(record)` stage 1 | C | mode-specific questions |
| SES-DONE-L | What was learned | Reflection continue | stage 2 | C | honest advancement copy |
| PRG | Program tab | Tab | tab .program | C | 6 phases, 90-day journey |
| WR | Weekly review | Checkpoint day reached | `.weeklyReview(day)` | — | required flow after checkpoint sessions |
| PT | Phase transition | Phase boundary | `.phaseTransition(id)` | — | |
| PC | Day 90 completion | Day 90 protocol complete | pendingCompletion | — | graduation moment |
| PROF | Profile tab | Tab | tab .profile | C | evidence maturity, rules, manual entry |
| LAB | Personal Lab | Profile → Lab | `.lab` | P | experiments: empty/library/setup/result |
| FUEL-V | Fuel detail | Profile/Fuel entry | `.fuel` | P | |
| FLOW | Flow Lab | Profile/Today supporting action | `.flowLab` | P | projects + conditions |
| FLOW-SETUP | Flow block setup | Create/join block | `.flowSetup` | P | protocol participation flag |
| ENV | Digital Environment Lab | Settings/Profile | sheet | C | profile, windows, interventions |
| ST-AUTH | Screen Time connect flow | Environment Lab | contextual permission sheet | F | requested/authorized/denied/revoked states |
| PAY | Paywall | Day-1 continuation, gated actions, Settings | sheet | — | StoreKit truth states: loading/available/pending/error |
| FV | Day-1 first-value continuation | Auto once after baseline | `.firstValue` | — | single automatic paywall entry point |
| SET | Settings | Profile → gear | sheet | C | subscription, program controls, notifications, data & privacy, about |
| DP | Data & Privacy | Settings | sheet | F | export JSON, erase all (2-step confirm + acknowledge) |
| LEGAL-P | Privacy Policy viewer | Paywall/Data&Privacy | sheet | F | bundled draft content |
| LEGAL-T | Terms viewer | Paywall/Data&Privacy | sheet | F | |
| MAN | Attention Operating Manual | Profile/Own Mode | sheet | C | evidence-backed sections, maturity labels |

## Screenshot coverage
See `QA/FullAppScreenshots/INDEX.md` for the captured dossier (EN + FR full,
DE/ES/IT stress subset), one representative iPhone 17 Pro shot per distinct
page/state per the screenshot rule.
