# App Store Connect — Release Checklist

Project: REBOOT (`REBOOT.xcodeproj`) · Branch: `ox/release-foundation-v1`

## Identity & signing
- [ ] Bundle ID: `com.kenatst.reboot` (verify in Signing & Capabilities)
- [ ] App Group: `group.com.kenatst.reboot` (app + DeviceActivityMonitorExtension)
- [ ] Team / signing certificates configured for all 4 targets (REBOOT, ShieldConfigurationExtension, DeviceActivityMonitorExtension, REBOOTTests)
- [ ] Version + build number set in ASC

## Entitlements
- [ ] **Family Controls (Distribution)** entitlement — requires requesting the Family Controls distribution permission from Apple before public TestFlight/App Store release. Request early.
- [ ] DeviceActivity entitlement present
- [ ] Verify `.entitlements` files match between app and monitor extension targets

## Subscriptions (App Store Connect)
- [ ] Create subscription group with `reboot.monthly`, `reboot.yearly`
- [ ] Localized display names/descriptions per locale
- [ ] Decide whether a real introductory offer exists. **The paywall shows "7-day free trial" ONLY when StoreKit reports an introductory offer** — do not advertise a trial in ASC metadata unless one is actually configured.
- [ ] Review screenshot of paywall for each territory language

## Privacy
- [ ] App Privacy label answers from `COMPLIANCE/APP_PRIVACY_ANSWERS.md`
- [ ] Privacy Manifest: `PrivacyInfo.xcprivacy` present (required-reason APIs audited) — see OPERATOR_INPUT_REQUIRED.md item 6
- [ ] Privacy Policy URL (hosted, public): **operator must host** — drafts at `LEGAL/privacy-policy.en.md` / `.fr.md`
- [ ] Terms of Service URL (hosted, public): **operator must host**
- [ ] Support URL + support email verified live

## Age rating
Recommended answer set: non-medical lifestyle/self-improvement; no user-generated content sharing; no gambling; unrestricted web access: none. Expected rating 4+/9+ depending on questionnaire; **do not** answer medical-questionnaire questions as if REBOOT were health/medical.

## Export compliance
- [ ] Standard encryption exemption (`ITSAppUsesNonExemptEncryption = NO` in Info.plist or declare in ASC) — app uses only standard iOS crypto

## Review readiness
- [ ] `COMPLIANCE/APP_REVIEW_NOTES.md` attached to the submission
- [ ] Demo path documented (onboarding → diagnosis → Day 1 free → paywall)
- [ ] Screen Time explanation ready for guideline 1.2/5.1.1 queries
- [ ] TestFlight external pass on a physical device (Family Controls behavior differs on device vs simulator)

## Screenshots & metadata
- [ ] Metadata drafts per locale in `APPSTORE/metadata/{en-US,fr-FR,es-ES,de-DE,it-IT}`
- [ ] Screenshot dossier from `QA/FullAppScreenshots/` trimmed to required ASC sizes
