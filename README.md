# Temple Trust — app for temple teams

The app a temple's own people — trust, committee, temple office — use to run
their temple's listing on **Darshan Saathi**. One Flutter codebase for
Android, iOS and the web.

It is the mobile companion to the temple portal (`/temple` on
temple.darshansaathi.com) and talks to the same Laravel backend in
[`temple-website`](https://github.com/PranayReddy10/temple-website) through
`/api/v1/trust`. The devotee app is
[`temple-app`](https://github.com/PranayReddy10/temple-app).

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
| Temple dashboard | Bookings today, received at the counter, upcoming events, events in review, reviews to answer, followers, likes, check-ins |
| Temple details | Short description, address, PIN, map position, phone, email, website, dress code, photography, phones, footwear, entry rules, queue information |
| Darshan timings | Darshan, aarti and special timings, every day or per weekday |
| Closures | Eclipses, renovations and days with changed hours |
| Events & festivals | With an image; published at once for verified temples, otherwise reviewed by the editors |
| Pujas & sevas | Fee (or free), timing, outside booking link, and in-app booking: per-person fee, party size, days ahead, daily capacity, instructions |
| Photos | Upload, choose the cover, hide or show, caption, delete |
| Seva bookings | By day, with gotram, nakshatram, phone and payment |
| Devotee reviews | Read, and reply as the temple |
| Scan at counter | Scan a devotee's seva booking code and mark them received (refused the second time), or look up a devotee's passport |

Name, deity, classification and the trust level stay with the editorial team,
as in the web portal.

## Super admins

Super admin accounts (the same as on `/admin`) sign in here too and get an
admin home instead of the team's:

| Screen | What it does |
| --- | --- |
| Waiting for you | Counts of requests to manage a temple, temples to list and events to review |
| Requests to manage | Call the requester, then approve or reject with a reason |
| Temples to list | Registrations from temple teams and suggestions from devotees, with photos: list as a draft, match to an existing temple, or reject |
| Events to review | Publish or reject events temple teams sent |
| All temples | Search and filter every temple, open any one with the full set of management screens, and publish, review, draft or archive it |

Editor accounts keep using the admin panel on the web.

## Running

```bash
flutter pub get
flutter run                       # device or emulator
flutter run -d chrome             # web
```

Pointing at another server (local Laravel, staging):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

The server can also be changed on the sign-in screen.

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
