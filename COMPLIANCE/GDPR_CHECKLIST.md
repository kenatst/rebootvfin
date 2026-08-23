# GDPR / UK GDPR Checklist — REBOOT

Status legend: ✅ implemented in product · 📋 documented (operator/counsel step) · ⚠️ requires counsel confirmation

| Requirement | Status | Where |
|---|---|---|
| Data minimization | ✅ | Only behavioral/self-reported data is stored; nothing collected beyond product function (`COMPLIANCE/DATA_MAP.md`) |
| Purpose limitation | ✅ | All stored data feeds only the training/guidance features described in-app |
| Storage limitation | ✅ | Local-only, user-erasable at any time; no retention beyond user choice |
| Lawfulness basis mapping | ⚠️ | Local-only processing; counsel to confirm basis characterization (no remote processing by operator) |
| Transparency | ✅ | In-app Privacy Policy viewer + bundled drafts; policy matches verified data flows |
| Right of access | ✅ | Settings → DATA & PRIVACY → "Export my REBOOT data" (complete JSON document) |
| Right to rectification | ✅ | Retake diagnosis rebuilds priors; sessions/rules editable or erasable via erase flow |
| Right to erasure | ✅ | Settings → DATA & PRIVACY → Erase All REBOOT Data (verified chain incl. notifications, monitoring, caches) |
| Right to portability | ✅ | Same JSON export; structured, machine-readable format |
| Right to object / restrict | ✅ | No remote processing exists to object to; all processing stops when data is erased |
| No tracking | ✅ | No ATT request, no IDFA, no analytics SDKs, no advertising |
| Sub-processor transparency | ✅ | None exist. Apple processes purchases (StoreKit) under Apple's terms — disclosed in policy §4 |
| International transfers | ✅ | None: no personal data leaves device (documented) |
| Security of storage | ✅ | iOS app sandbox; no personal data written to logs (release audit pass) |
| Breach notification readiness | 📋 | No central breach surface exists (local-only); operator contact route documented in OPERATOR_INPUT_REQUIRED.md |
| DPO appointment assessment | 📋 | Operator decision; local-only processing likely below DPO-mandatory threshold — confirm with counsel |
| DPIA screening | 📋 | Recommended: formal screening note. Risk profile is low (local-only, no special-category data claimed, non-medical positioning) |
| Records of processing (Art. 30) | 📋 | DATA_MAP.md is the working basis; formalize as RoPA appendix |
| Children's data | ✅ | Not directed under 13; nothing transmissible from a child's device |

## Special-category data check
REBOOT does **not** request, and structurally cannot receive remotely: health data, biometrics, or any Art. 9 GDPR categories. Users may *voluntarily type* reflections that could touch sensitive topics; these never leave the device, which keeps the operator out of the processing chain entirely.
