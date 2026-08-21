# CI/CD Setup — Merchant App

This repo ships GitHub Actions pipelines plus Fastlane for shipping to the
**Google Play Store** and **Apple App Store / TestFlight**.

> **State before this setup:** the repo had no CI/CD. Android release builds were
> signed with the **debug** key and iOS used a **personal** signing team — neither
> is publishable to the stores. The pipeline below fixes both, but you must supply
> the signing material listed under *Required secrets*.

## Workflows

| File | Trigger | What it does |
|------|---------|--------------|
| `.github/workflows/ci.yml` | every PR + push to `main`/`develop` | `flutter pub get`, format check (non-blocking), `flutter analyze`, `flutter test`, debug APK build |
| `.github/workflows/release-android.yml` | **push to `main`** (`internal`), **tag `v*`** (`production`), or manual (chosen track) | builds a **signed AAB** and uploads to Google Play |
| `.github/workflows/release-ios.yml` | **push to `main`**, **tag `v*`**, or manual | builds a **signed IPA** and uploads to **TestFlight** |

**Auto-release on merge to `main`** ships to testing channels only — Play
`internal` track and TestFlight. Production is never auto-published; it requires
a `v*` tag or a manual run.

Promoting to production:

```bash
git tag v1.0.1
git push origin v1.0.1
```

…or run either release workflow manually from the Actions tab (Android exposes a
track dropdown).

### Behavior before secrets are configured

Both release workflows start with a `check-secrets` job. If any required secret
is missing, the release job is **skipped** (grey in the Actions UI) rather than
failed, and the run summary lists exactly which secrets are missing. This keeps
`main` green until you finish the store setup. Once all secrets are present the
release job runs automatically — no workflow changes needed.

### Build numbers

Both release workflows pass `--build-number=${{ github.run_number }}` so every
upload gets a unique, increasing version. Play and App Store both reject
duplicate build numbers, so **do not** rely on the static `+1` in `pubspec.yaml`
for store uploads — the run number overrides it in CI.

## Fastlane layout

```
Gemfile                      # fastlane dependency (root)
android/fastlane/Appfile     # package name + Play service-account key
android/fastlane/Fastfile    # `deploy` (upload AAB) + `promote` lanes
ios/fastlane/Appfile         # bundle id
ios/fastlane/Fastfile        # `beta` (build IPA + TestFlight) + `certificates` lanes
ios/ExportOptions.plist      # app-store export config
```

## Required GitHub secrets

Set these under **Settings → Secrets and variables → Actions**.

### Android → Google Play

| Secret | How to get it |
|--------|---------------|
| `ANDROID_KEYSTORE_BASE64` | Your upload keystore, base64-encoded: `base64 -i upload-keystore.jks \| pbcopy` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias (e.g. `upload`) |
| `ANDROID_KEY_PASSWORD` | Key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play service-account JSON, base64-encoded. Create it in Google Cloud → grant it access in Play Console → Users & permissions |

Generate an upload keystore locally if you don't have one:

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

> The app must be created once in the Play Console and an initial AAB uploaded
> manually before the API can push to it.

### iOS → App Store / TestFlight

> Requires a **paid Apple Developer Program** membership. The current Xcode
> project uses a personal team (`BPC676HCRQ`) that cannot create App Store
> provisioning profiles — replace it with the paid team's ID in
> `ios/Runner.xcodeproj` and `ios/ExportOptions.plist`.

| Secret | How to get it |
|--------|---------------|
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API → key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Same page → Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | The downloaded `AuthKey_XXXX.p8`, base64-encoded |
| `MATCH_GIT_URL` | Private git repo URL that stores encrypted certs/profiles (fastlane match) |
| `MATCH_PASSWORD` | Passphrase used to encrypt the match repo |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64 of `user:personal_access_token` for the match repo |

One-time signing bootstrap (run locally, with the paid account):

```bash
cd ios
bundle install
bundle exec fastlane ios certificates   # creates + stores App Store cert/profile in the match repo
```

## Environment files

`env/dev.json` and `env/prod.json` are consumed via
`--dart-define-from-file`. The app reads them through `String.fromEnvironment`:

| Key | Read by |
| --- | --- |
| `API_BASE_URL` | `ApiClient.baseUrl` — bare host, no `/api/food` suffix |
| `WS_URL` | `SocketService.wsUrl` |
| `USE_MOCK` | `ApiClient.useMock` — `true` serves canned data offline |
| `ENV` | nothing yet |
| `APP_*_FIREBASE_*` | `DefaultFirebaseOptions` in `lib/firebase_options.dart` |

### Firebase / push

Both env files now carry real credentials, against two separate projects:

| File | Firebase project | Project number | Android package | iOS bundle |
| --- | --- | --- | --- | --- |
| `env/dev.json` | `dev-merchant-4619a` | 206020784191 | `com.mass.merchant_app.dev` | `com.mass.merchantApp.dev` |
| `env/prod.json` | `prod-merchant-8d684` | 812699956693 | `com.mass.merchant_app` | `com.mass.merchantApp` |

The registered ids match what each build actually produces: debug builds add
`.dev` (via `applicationIdSuffix` on Android, the Debug configuration on iOS,
and `tool/deploy_dev.sh` for TestFlight), release builds drop it.

`apiKey` and `appId` are per-app; `messagingSenderId`, `projectId` and
`storageBucket` are per-project. Values come from `google-services.json`
(Android) and `GoogleService-Info.plist` (iOS) — neither file is committed, the
defines replace them.

If a value is ever unknown, leave it as an empty string. `main.dart` only calls
`Firebase.initializeApp` when `appId` and `projectId` are both non-empty, so
blanks disable push cleanly. A dummy value such as `CHANGE_ME` is worse than
nothing — it satisfies the guard, so init runs with a bogus config and iOS
aborts on an uncatchable Objective-C exception at launch.

> **Release builds are now internally inconsistent.** `env/prod.json` pairs the
> production Firebase project with `API_BASE_URL` still pointing at
> `driver-api-dev.nutchaphut.dev`. A release build therefore registers its FCM
> token under sender 812699956693 and hands it to the dev backend, which pushes
> through whichever project *it* is configured with — a sender mismatch means
> those pushes are rejected. Point `API_BASE_URL` at the production host before
> relying on push in a release build.

## Notes / prerequisites

- Flutter is pinned to **3.41.6** in all workflows — bump in one place per file if you upgrade.
- `build_runner` is intentionally not used: this project has no code generation.
- iOS release runs on `macos-14`; Android and CI run on `ubuntu-latest`.
- Secrets files (keystore, `key.properties`, service-account JSON, `.p8`) are all git-ignored — see `.gitignore`.
