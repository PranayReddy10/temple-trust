# Releasing Darshan Saathi Trust on Google Play

Package name: `com.darshansaathi.temple_trust`

## 1. Make the upload key (once, on your own computer)

```bash
keytool -genkey -v -keystore ~/keys/darshan-saathi-trust-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

It asks for a password and your name/organisation. Keep the `.jks` file
and both passwords safe and backed up (a password manager plus a second
copy off the computer). Do not put them in Git, email or chat.

With **Play App Signing** (the default for new apps), Google holds the key
that signs what devotees install; this file is only the *upload* key. If it
is ever lost, Play Console → App integrity → *Request upload key reset*
replaces it.

## 2. Tell the build where it is

Copy `android/key.properties.example` to `android/key.properties` and fill
it in. `key.properties`, `*.jks` and `*.keystore` are in .gitignore.

## 3. Raise the version

In `pubspec.yaml`, `version: 1.0.0+7` means version name 1.0.0 and version
code 7. Every upload needs a higher version code than the last one.

## 4a. Build it on GitHub (recommended)

`.github/workflows/release-android.yml` analyses, tests, builds and signs
the bundle on GitHub, and uploads it to Play when a service account is set.
Add these repository secrets once (Settings → Secrets and variables →
Actions):

| Secret | Value |
|---|---|
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | `base64 -w0 ~/keys/darshan-saathi-trust-upload.jks` (macOS: `base64 -i … `) |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | optional, see below |

Then Actions → **Release Android** → Run workflow → pick the track. The
signed `app-release.aab` is attached to the run (Artifacts). The version
code is the run number + 100, so it always goes up; the version name is
`version:` in `pubspec.yaml`.

**Automatic upload to Play** (after the first release, which Play requires
you to upload by hand): Google Cloud console → create a service account and
a JSON key for it → Play Console → Users and permissions → Invite new user
→ the service account's email, with *Release apps to testing tracks* and
*Release to production* for this app → paste the JSON file's contents into
`PLAY_SERVICE_ACCOUNT_JSON`. Internal, alpha and beta releases go live to
testers at once; production is uploaded as a draft to roll out in Play
Console.

## 4b. Or build it on your computer

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

The bundle is `build/app/outputs/bundle/release/app-release.aab`.

Check it is signed with your key, not the debug key:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

The owner shown should be the name you gave in step 1, not "Android Debug".
Without `key.properties` the build falls back to the debug key, which Play
Console refuses.

## 5. First upload, and the Play Console checklist

Before the first release Play Console asks for the items in
[PLAY_LISTING.md](PLAY_LISTING.md): store listing text and graphics, the
privacy policy and account-deletion links, the Data safety answers, a
reviewer sign-in, content rating and target audience. All of it is written
there, ready to paste.

## 6. Upload

Play Console → the app → Test and release → Internal testing (first), then
Production → Create new release → upload `app-release.aab`.

## 7. Link it from the devotee app

Once the Trust app is live, its Play Store page is
`https://play.google.com/store/apps/details?id=com.darshansaathi.temple_trust`,
which the devotee app already opens from "From the temple? Get the Darshan
Saathi Trust app". Nothing to change unless the package name changes.
