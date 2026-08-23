# Screenshot Dossier — INDEX

Device: iPhone 17 Pro simulator (`iPhone 17 Pro`, iOS 26.2). One representative
shot per distinct page/state per the screenshot rule. QA routes: `-qaState`
(AppState phase JSON in `QA/states/`) and `-qaSeed <name>` (deterministic seeds,
DEBUG-only; isolated from production persistence).

Locale note: FR full pass + DE/ES/IT stress subset per the release-foundation brief.

## English (QA/FullAppScreenshots/en/)

| File | Screen | State | Route |
|---|---|---|---|
| 01_onboarding_page1.png | Cinematic onboarding p1 | chaos artwork | -qaState onboarding1 |
| 02_onboarding_page2.png | Cinematic p2 | recognition | -qaState onboarding2 |
| 03_onboarding_page3.png | Cinematic p3 | possibility | -qaState onboarding3 |
| 04_onboarding_page4.png | Cinematic p4 | calm | -qaState onboarding4 |
| 05_onboarding_page5.png | Cinematic p5 | personalization | -qaState onboarding5 |
| 06_onboarding_page6.png | Cinematic p6 (DAY 001/090) | commitment | -qaState onboarding6 |
| 07_dissolve.png | Dissolve interstitial | transition | -qaState dissolve |
| 08_diagnosis_q1_empty.png | Diagnosis Q1 | unanswered | -qaState diagnosis_q0 |
| 08_diagnosis_step2..8.png | Diagnosis progression | partially answered | -qaState diagnosis_q{2,4,6,8} |
| 09_report_full.png | Your starting point | all priors answered | -qaState report_full |
| 09_report_unknowns.png | Starting point honest unknowns | minimal answers | -qaState report_unknown |
| 10_today_day01.png | Today Day 1 baseline | free OBSERVE prescription | -qaSeed day1 |
| 11_today_day05_stay.png | Today Day 4 STAY | energy prompt + env context | -qaSeed stay |
| 12_today_day12_recall.png | Today Day 5 RECALL | recall prescription | -qaSeed recall |
| 13_today_recovery.png | Recovery day (NOTHING) | after hard session | -qaSeed rest |
| 14_session_running.png | Active session timer | OBSERVE running | -qaSeed running |
| 15_session_done.png | Session complete → reflection | Day-1 baseline done | -qaSeed done |
| 16_today_day45_deepen.png | Today Day 45 Deepen | RECALL prescription | -qaSeed programMidPhase |
| 17_today_day65_flow.png | Today Day 65 Find Conditions | flow-phase observe | -qaSeed programDay65FlowConditions |
| 18_day090_final_synthesis.png | Today Day 90 final synthesis | last protocol day | -qaProduct day90active.json |
| 19_own_mode.png | Own Mode Today | post-90 self-directed | -qaSeed programCompleted |
| 19b_own_mode_alt.png | Own Mode variant | suggestion card | -qaSeed programCompleted (2nd run) |
| 20_flow_lab_empty.png | Flow Lab empty | no projects | -qaSeed flowEmpty |
| 20_flow_project_new.png | Flow Lab with project | active project | -qaSeed flowProjectNew |
| 21_flow_conditions_mature.png | Flow conditions learned | repeated signals | -qaSeed flowMaturePatterns |
| 22_personal_lab_suggested.png | Personal Lab suggested test | phone distance | -qaSeed labSuggested |
| 23_lab_active_midway.png | Lab active experiment | comparison 1 of 3 | -qaSeed labActiveMidway |
| 23_personal_lab_result_keep.png | Lab KEEP result | past tests | -qaSeed labResultKeep |
| 24_lab_result_inconclusive.png | Lab INCONCLUSIVE result | extend option | -qaSeed labResultInconclusive |
| 24_paywall.png | Paywall | products-unavailable truth state (no StoreKit config in sim) | -qaPaywall |
| 25_flow_block_setup.png | Flow block setup | task + conditions | -qaSeed flowBlockSetup |
| 26_flow_block_running.png | Active Flow block | protected session | -qaSeed flowBlockRunning |
| 27_today_day7_checkpoint.png | Weekly review | day-7 checkpoint required flow | -qaSeed programDay7Checkpoint |
| 28_phase_transition.png | Phase transition | Control Input intro | -qaSeed programDay8Transition |
| 29_today_day82_own_system.png | Today Day 82 Own-the-System | late-program independence | -qaSeed programDay82Mature |
| 30_profile_low_evidence.png | Today Day-1 low-evidence strip | honest empty evidence | -qaSeed profileSparse |

## French full pass (QA/FullAppScreenshots/fr/)

| File | Screen | Verification |
|---|---|---|
| 01_onboarding_page1.png | Onboarding p1 FR | "Votre attention est en train d'être tirée en quatre" ✓ |
| fr_06_onboarding_page6.png | Onboarding p6 FR | localized CTA |
| fr_09_report_full.png | Report FR | localized labels |
| fr_10_today_day01.png | Today Day 1 FR | "Observe ton focus naturel" / tabs Aujourd'hui·S'entraîner·Programme·Profil ✓ |
| fr_11_today_stay.png | Today STAY FR | |
| fr_13_today_recovery.png | Recovery FR | "Donne à ton esprit moins à quoi réagir" / "Commencer la pause" ✓ |
| fr_14_session_running.png | Session running FR | |
| fr_15_session_done.png | Session done FR | |
| fr_19_own_mode.png | Own Mode FR | |
| fr_21_flow_conditions.png | Flow conditions FR | |

## Localization stress subset

| File | Locale | Notes |
|---|---|---|
| de_stress/de_today_day01.png | German | longest-language check passed: no clipping beyond known title truncation |
| de_stress/de_report.png | German | report layout under long words |
| de_stress/de_own_mode.png | German | Own Mode card |
| es_stress/es_today_day01.png | Spanish | "Observa tu foco natural" / Hoy·Entrenar ✓ |
| es_stress/es_own_mode.png | Spanish | Own Mode |
| it_stress/it_onboarding_page1.png | Italian | cinematic page |
| it_stress/it_today_day01.png | Italian | "Osserva la tua concentrazione naturale" / Oggi·Allenati ✓ |

## Known gaps (deliberate)
- Settings/Data&Privacy/Legal sheets captured within EN pass flows; not duplicated per locale (same layout engine).
- Permission dialogs (Screen Time/notification) are OS-rendered and vary by runtime; covered by code-level review.
