# REBOOT Data Map

Verified against the codebase at `ox/release-foundation-v1`. Every row reflects actual storage code paths.

| # | Data category | Source | Where stored | Leaves device? | Retention | Export | Delete |
|---|---|---|---|---|---|---|---|
| 1 | Diagnosis answers | User input (onboarding) | `UserDefaults.standard` key `reboot.state.v1` (`AppState.persist`) | No | Until erased / retake diagnosis | Yes — `RebootDataExport` JSON | Erase All / Retake |
| 2 | Attention profile & priors | Derived from diagnosis + sessions | `reboot.product.v8` payload, `profile` field | No | Program lifetime | Yes | Erase All |
| 3 | Session records (mode, duration, switches, return timing, difficulty, energy, reflections) | Session lifecycle | `reboot.product.v8`, `sessions` | No | Program lifetime | Yes | Erase All |
| 4 | Personal rules | Derived + user-created | `profile.personalRules` in v8 payload | No | Until retired/erased | Yes | Erase All |
| 5 | Evidence observations | Derived from sessions | `observations` + `profile.observations` | No | Program lifetime | Yes | Erase All |
| 6 | Personal Lab experiments | User-designed comparisons | `personalLab` in v8 payload | No | Program lifetime | Yes | Erase All |
| 7 | Fuel context (energy/sleep/meal/movement) | User check-ins | `fuel` in v8 payload | No | Rolling sampling window | Yes | Erase All |
| 8 | Flow projects, plans, evidence | User-created projects + blocks | `flow` in v8 payload | No | Program lifetime | Yes | Erase All |
| 9 | Digital Environment profile & interruption events | Derived + self-report | `digitalEnvironment` in v8 payload | No | Program lifetime | Yes | Erase All |
| 10 | Focus Windows (Digital Environment V2) | User-configured schedules | `digitalEnvironment.focusWindows` in v8 | No | Until deleted/erased | Yes | Erase All (+ monitoring stop) |
| 11 | Screen Time selection | FamilyActivitySelection | Opaque token data in `reboot.environment.v1` (`EnvironmentStore`) | **No** — tokens never leave device; Apple holds them on-device | Until cleared/erased | **No** (opaque; excluded by design) | Clear selection / Erase All |
| 12 | DeviceActivity threshold events | DeviceActivityMonitorExtension → App Group file `threshold-events.json` | Shared app group container | Between app+extension on same device only | Deduped into observations | Observations yes; raw events no | Erase All removes file |
| 13 | Weekly reviews & guidance decisions | Generated during program | `programState.reviews`, `guidanceDecisions` | No | Program lifetime | Yes | Erase All |
| 14 | Operating Manual content | Synthesized from evidence | Recomputed live from stores; text export via ShareLink | Only via explicit share | n/a (derived) | Yes | Falls out of erase |
| 15 | Notification preferences | User settings | `reboot.notifications.preferences.v1` | No | Until changed/erased | No (settings, not personal record) | Erase All resets |
| 16 | Scheduled notifications | Local scheduling | UNUserNotificationCenter | Delivered locally by iOS | Until cancelled | No | Erase All cancels all |
| 17 | Subscription entitlement cache | StoreKit verification result | `reboot.cached.entitlement.v1` | No | Until next refresh | No (Apple owns purchase history) | Erase All clears cache; Apple history unaffected |
| 18 | Purchase transactions | Apple StoreKit | Apple's servers under Apple privacy policy | Handled by Apple | Per Apple terms | Via Apple | Via Apple |

## Explicitly NOT collected
- No analytics or crash SDKs (no third-party SDKs at all).
- No advertising identifiers; ATT not requested.
- No accounts, no backend, no cloud sync.
- No opaque-token decoding: Screen Time selections are never resolved to app names.
- No foreground surveillance of device usage.

## Storage notes
- All REBOOT-owned persistence is in `UserDefaults.standard` plus one App Group JSON file shared with the DeviceActivityMonitor extension (event names + timestamps only, per `ThresholdEventRecord`).
- DEBUG-only QA runs are diverted to ephemeral scratch `UserDefaults` suites and purge any legacy production keys they find (`ProductStore.purgeProductionProductState`), so QA state can never persist for a real launch.

## Counsel review flags
- Legal basis characterization (legitimate interest vs consent) for local-only processing — mark for counsel.
- Whether the App Group file needs mention as a "recipient" — treated here as same-device processing, not a transfer.
