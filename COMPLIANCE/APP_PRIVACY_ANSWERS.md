# App Privacy Label — Recommended ASC Answers

Derived from the verified implementation (see `COMPLIANCE/DATA_MAP.md`). REBOOT transmits **no data off-device**.

## Data Used to Track You
- None. (No tracking across apps/websites; no ATT request; no IDFA.)

## Data Linked to You
- **None collected.** All product data is stored locally on the user's device and is never transmitted to the developer or any third party.

## Data Not Linked to You
- **None.** (Nothing leaves the device.)

## Contact Info / Identifiers / Purchases
- Purchases are handled by Apple via StoreKit under Apple's privacy terms. The developer receives no purchase or user data. The local entitlement cache (subscription status + expiry) never leaves the device.

## Answering the questionnaire
For every category, answer "Data NOT collected" — because nothing is transmitted, this is truthful for every App Store privacy question. Keep `PrivacyInfo.xcprivacy` aligned: no tracking domains, no non-required-reason API usage beyond declared ones.
