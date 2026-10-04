# Google Play: Darshan Saathi Trust — what to enter

Everything Play Console asks for before the first release, ready to paste.
Package: `com.darshansaathi.temple_trust`.

## Before you start

1. **The server first.** The app needs the backend changes on
   `claude/keen-brahmagupta-jv4dja` (temple-website), including
   `DELETE /api/v1/trust/me` for account deletion. Merge and deploy that to
   temple.darshansaathi.com before the app goes to review.
2. **Policy pages.** In the admin panel → Pages, open *Privacy policy* and
   *Delete your account* and use **Reset to default** (or copy the new
   "Temple teams" paragraphs) so the live pages describe the Trust app.
3. **A reviewer account.** Google's reviewers must be able to sign in. Make
   an account in the app (e.g. `play-review@darshansaathi.com`), then in the
   admin panel approve it as *manager* of one published demo temple, so the
   reviewer sees a dashboard rather than an empty "Connect your temple"
   screen. Do not make it the owner of a temple that takes real money.

## Main store listing

**App name** (30 max)
Darshan Saathi Trust

**Short description** (80 max)
Run your temple on Darshan Saathi: timings, sevas, bookings, hundi and payouts.

**Full description** (4000 max)

Darshan Saathi Trust is the app for temple teams — trustees, secretaries, priests and volunteers — who manage their temple on Darshan Saathi, where devotees find temples, see darshan timings, book sevas and give to the online hundi.

Keep your temple's page right
• Darshan and aarti timings, with different hours on Saturday and Sunday, and closures for eclipses or festivals
• Sevas and pujas with fees, time slots and in-app booking
• Festivals, bhajans and events, with registrations and tickets
• Photos, cover image, contact details, dress code and entry rules
• Reply to devotees' reviews

At the counter
• Scan a devotee's seva booking or event ticket and mark them received
• Find a booking by phone number or reference when a devotee has no phone
• Stamp devotees' temple passports
• Print the temple's check-in QR poster

Money, clearly
• Today's bookings and hundi at a glance, with daily, monthly and yearly reports
• Every settlement paid to the temple, with what it covered and the bank reference
• The temple's owner adds the bank account and verification documents once; payouts go straight to the temple's bank
• Switch the online hundi on or off

Getting started
Search for your temple and ask to manage it, or register a temple that is not listed yet. Our team checks every request before access is given.

In English, తెలుగు, हिन्दी, தமிழ் and ಕನ್ನಡ.

Questions? Write to support@darshansaathi.com or use Help & support in the app.

**App category:** Business
**Tags:** Business, Productivity (as offered)
**Contact email:** support@darshansaathi.com
**Website:** https://darshansaathi.com
**Privacy policy:** https://darshansaathi.com/privacy-policy

**Graphics**
- App icon 512×512 PNG (from `assets/` / the launcher icon)
- Feature graphic 1024×500
- At least 2 phone screenshots (1080×1920 or similar): the temple dashboard, timings, bookings, scan, finance. Take them from the reviewer/demo account so no real devotee's name or phone appears.

## App content (Policy → App content)

**Privacy policy:** https://darshansaathi.com/privacy-policy

**Ads:** No, the app does not contain ads.

**App access:** All or some functionality is restricted → add instructions:
> Sign in with the email and password below. The account manages the demo temple "…". Payments verification is not needed to review the app.
> Email: play-review@darshansaathi.com · Password: (the one you set)

**Content rating:** Category *Utility, Productivity, Communication, or Other*. Violence, sexuality, language, controlled substances, gambling: No. Users can interact or exchange content: Yes (temples reply to devotees' reviews; reviews are moderated). Shares user location with other users: No. Purchases of digital goods: No.

**Target audience:** 18 and over. Not designed for children.

**News app:** No. **COVID-19 tracing:** No. **Government app:** No. **Financial features:** None of the listed (the app shows a temple's own receipts and settlements; it does not lend, invest or hold money for users).

**Account deletion**
- The app lets users create accounts: Yes
- Delete account URL: https://darshansaathi.com/account-deletion
- In the app: Account → Delete account (password + type DELETE)

### Data safety

Data is encrypted in transit: **Yes** (HTTPS only).
Users can request that data be deleted: **Yes**.

| Data type | Collected | Shared | Optional? | Purposes |
|---|---|---|---|---|
| Personal info → Name | Yes | No | Required | Account management, App functionality |
| Personal info → Email address | Yes | No | Required | Account management, App functionality |
| Personal info → Phone number | Yes | No | Required | Account management, App functionality |
| Personal info → Other info (Aadhaar number, Aadhaar card, temple proof) | Yes | No | Optional (only a temple's owner, to receive payments) | Fraud prevention, security and compliance |
| Financial info → Other financial info (bank account / UPI for payouts) | Yes | No | Optional (owner only) | App functionality |
| Location → Precise location | Yes | No | Optional (only when asking to manage or registering a temple) | Fraud prevention, security and compliance |
| Photos and videos → Photos | Yes | No | Optional | App functionality (temple photos, verification photo) |
| App activity → Other user-generated content (temple details, review replies, support messages) | Yes | No | Optional | App functionality |
| App info and performance → Crash logs / Diagnostics | No | — | — | — |
| Device or other IDs | No | — | — | — |

"Shared" means given to another company; data processed for us by our
hosting and email providers counts as *not* shared under Play's rules.
Location is collected only while the app is open, at the moment the team
member taps "Use my current location".

### Permissions to explain if asked

- **Camera** — scanning devotees' booking, ticket and passport QR codes at the counter, and taking temple photos.
- **Location (foreground only, precise)** — confirming a person is at the temple when they ask to manage it or register it. Not used in the background.

## Release

1. Test and release → **Internal testing** → create a release → upload the
   `app-release.aab` (from GitHub Actions → Release Android → Artifacts, or
   your own build) → add testers (your team's Gmail addresses) → roll out.
2. Install from the testers' link, sign in with a real temple account and
   the reviewer account, try scan, timings, finance and Delete account (on a
   spare account).
3. **Production** → create release → promote the same build → send for
   review. Reviews of a new app usually take a few days.
4. New personal developer accounts must first run a closed test with at
   least 12 testers for 14 days before production access is granted; if
   Play Console shows that requirement, use *Closed testing* for step 1.
