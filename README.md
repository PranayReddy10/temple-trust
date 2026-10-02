# Darshan Saathi Trust — app for temple teams

The app a temple's own people — trust, committee, temple office — use to run
their temple's listing on **Darshan Saathi**. One Flutter codebase for
Android, iOS and the web.

It is the mobile companion to the temple portal (`/temple` on
temple.darshansaathi.com) and talks to the same Laravel backend in
[`temple-website`](https://github.com/PranayReddy10/temple-website) through
`/api/v1/trust`. The devotee app is
[`temple-app`](https://github.com/PranayReddy10/temple-app).

The app is called **Darshan Saathi Trust** on the phone (`Brand.appName`, the
Android label, the iOS display name and the web manifest). Its icon is the
Darshan Saathi gopuram in brass on temple-door teak with a TRUST band, drawn
by `tool/brand/render.js` (`node tool/brand/render.js`, needs Playwright's
Chromium), which also writes the logo shown on the welcome screen.

## How a temple gets in

1. **Create an account** — name, email, mobile number, password. Temple
   portal accounts sign in with the same email and password.
2. **Find the temple** and ask to manage it (as *owner* — the trust or
   office — or *manager*), with a note on how you are connected.
3. **Temple not listed?** Register it: name, place, description, timings,
   contact and at least one photo. It goes to the editors' review queue.
4. **Staff confirm** — usually by calling the number on the account — under
   Admin → Temple access. Once approved the temple appears on the home
   screen. A registered temple comes back to the account as a request to
   manage it, confirmed the same way.

An account with no approved temple can see nothing but its own requests.

## What a team manages

| Screen | What it does |
| --- | --- |
| Temple dashboard | Amount paid for today's sevas, bookings today, received at the counter, upcoming events, events in review, reviews to answer, followers, likes, check-ins |
| Temple details | Short description, address, PIN, map position, phone, email, website, dress code, photography, phones, footwear, entry rules, queue information |
| Darshan timings | Darshan, aarti and special timings, every day or per weekday |
| Closures | Eclipses, renovations and days with changed hours |
| Events & festivals | With an image; published at once for verified temples, otherwise reviewed by the editors |
| Pujas & sevas | Fee (or free), timing, outside booking link, and in-app booking: per-person fee, party size, days ahead, daily capacity, instructions, and **time slots** (like show times: from–to, people per slot, weekdays; "Make slots" fills e.g. 9:00–12:00 hourly) |
| Photos | Upload, choose the cover, hide or show, caption, delete |
| Temple home | Cover photo (change it from the camera, the phone, or one already uploaded), the full address with district and state, today's seva money, **today's hundi** and the month's, and **Your share**: what the temple receives and what the platform keeps, on sevas/tickets and on hundi gifts. Pull down to refresh on every screen |
| Seva bookings | Tap one to see the ticket exactly as the devotee sees it (QR, date, time, people, reference) and **Mark received**. By day, with gotram, nakshatram, phone and payment, and the day's totals: booked, people, received, amount paid |
| Finance | Any day's bookings and amount, by seva; the month; what is due to the temple after the platform fee, being paid and paid to date; every payout with its bank reference (UTR) and the bookings it covers; the payout bank account or UPI id (owner only, verified by staff after any change) |
| Events: bhajan gatherings & tickets | Type *Bhajan gathering*, every-week repetition, mandali name, open to all, song list, and *Devotees can join in the app*: free "I'll join" or a ticket price per person with a limit per date. Each event shows who is going; **Attendees** lists them by date with the amount paid |
| Online hundi | Gifts devotees made in the app, today / this month / in all, with donor ("A devotee" when anonymous) and purpose; the owner switches the hundi on or off |
| Devotee reviews | Read, and reply as the temple |
| Scan at counter | Scan a devotee's seva or event ticket and mark them received (refused the second time, before its day and after it), or scan a devotee's passport and **mark visited today**, which puts the temple's verified stamp in their passport |
| Help & support | Ask the Darshan Saathi team in the app (payouts, bookings, listing, anything else). Questions land in Admin → Support & reports and the answers come back as a conversation |
| Temple QR code | The temple's signed check-in code to show at the gate (devotees scan it for their passport stamp), with the printable A4 poster and the link |

Name, deity, classification and the trust level stay with the editorial team,
as in the web portal.

**Location is taken live.** Asking to manage a listed temple, registering a
temple, or changing its location
uses the phone's GPS at the temple ("Use my current location"); coordinates
cannot be typed. The fix must be accurate to 150 m (mock locations are
refused), and the server rejects a request, registration or location change
without it. A request to manage a temple is also refused more than 500 m from
the temple's map pin; staff see where each request was sent from.

## Super admins

Super admin accounts (the same as on `/admin`) sign in here too and get an
admin home instead of the team's:

| Screen | What it does |
| --- | --- |
| Waiting for you | Counts of requests to manage a temple, temples to list and events to review |
| Requests to manage | Call the requester, then approve or reject with a reason |
| Temples to list | Registrations from temple teams and suggestions from devotees, with photos: list as a draft, match to an existing temple, or reject |
| Events to review | Publish or reject events temple teams sent |
| Finance & settlements | Seva payments today and this month, what each temple is owed, **Settle** to prepare a payout, the account to pay, then **Mark paid** with the UTR (or cancel) — the same as Admin → Finance on the web |
| All temples | Search and filter every temple, open any one with the full set of management screens, and publish, review, draft or archive it |

Editor accounts keep using the admin panel on the web.

## Running

```bash
flutter pub get
flutter run                       # device or emulator
flutter run -d chrome             # web
```

Builds talk to `https://temple.darshansaathi.com`; there is no server setting
in the app. For local Laravel or staging, build with:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

```bash
flutter analyze
flutter test
```

## Layout

```
lib/
  core/            api client, session, models, theme, shared widgets
  features/
    auth/          sign in and create account
    home/          your temples, requests and registrations
    onboarding/    find and claim a temple; register a missing one
    temple/        dashboard and each management screen
    counter/       booking and passport scanner
    account/       name, phone, password, sign out
```

Build-time settings: `API_BASE_URL`, `BRAND_NAME`, `TRUST_APP_NAME`,
`BRAND_SUPPORT_EMAIL` (all `--dart-define`).
