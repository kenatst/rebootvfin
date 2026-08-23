# OPERATOR INPUT REQUIRED — Launch Blockers

Only items Ox cannot know. Everything else is implemented or documented.

| # | Item | Blocks | Owner action |
|---|---|---|---|
| 1 | **Legal entity name + address** (`{{LEGAL_ENTITY_REQUIRED}}` in `REBOOT/Shipping/LegalConfiguration.swift`, `LEGAL/*.md`) | Privacy Policy, Terms, ASC "Copyright" | Replace token everywhere; confirm registered entity |
| 2 | **Governing jurisdiction** (`{{GOVERNING_JURISDICTION_REQUIRED}}`) | Terms §14 | Counsel decision |
| 3 | **Production support email** (currently `support@rebootattention.com` placeholder) | ASC support contact, in-app links | Confirm/replace in `LegalConfiguration.swift` |
| 4 | **Hosted Privacy Policy + Terms URLs** (currently `rebootattention.com/privacy`, `/terms`) | ASC privacy/Terms URLs, in-app "View Web Version" | Host the drafts (legal review first) and confirm final URLs |
| 5 | **Legal review sign-off** on `LEGAL/privacy-policy.*.md` and `LEGAL/terms-of-service.*.md` | Public release | Counsel review of drafts (they are high-quality drafts, not counsel-approved documents) |
| 6 | **Privacy Manifest** (`PrivacyInfo.xcprivacy`) | App Store submission (May 2024+ requirement) | Create with required-reason declarations matching final code (UserDefaults CS1917 etc.); verify no other required-reason APIs are added before submission |
| 7 | **Family Controls distribution entitlement** | TestFlight / App Store build with Screen Time features | Request from Apple (developer.apple.com contact form) — approval can take days |
| 8 | **StoreKit products** `reboot.monthly` / `reboot.yearly` | Live purchases | Create in ASC with real prices; decide on introductory offer (paywall auto-detects; never hardcodes) |
| 9 | **App Review demo account / hardware** | Review pass | None needed (no accounts); attach `COMPLIANCE/APP_REVIEW_NOTES.md` |

## Non-blockers (recommended)
- Formal DPIA screening record (GDPR_CHECKLIST.md 📋 rows)
- Decide App Store category: Lifestyle vs Productivity
