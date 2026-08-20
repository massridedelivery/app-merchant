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

`env/dev.json` carries the real values for the **dev-merchant-4619a** project
(project number 206020784191), so debug builds get working FCM.
`env/prod.json` still holds empty strings: no production Firebase project
exists yet, and push is simply off there.

Leave unknown values as empty strings. `main.dart` only calls
`Firebase.initializeApp` when `appId` and `projectId` are both non-empty, so
blanks disable push cleanly. A dummy value such as `CHANGE_ME` is worse than
nothing — it satisfies the guard, so init runs with a bogus config and iOS
aborts on an uncatchable Objective-C exception at launch.

The dev registration covers the `.dev` variants only:

| Platform | Registered in Firebase | Produced by |
| --- | --- | --- |
| Android | `com.mass.merchant_app.dev` | debug builds (`applicationIdSuffix`) |
| iOS | `com.mass.merchantApp.dev` | Debug config, and `tool/deploy_dev.sh` |

Release builds ship `com.mass.merchant_app` / `com.mass.merchantApp`, which are
not registered in the dev project — expected, since they read `env/prod.json`
and have push off anyway. Registering a production Firebase app means filling
`env/prod.json` and nothing else; no workflow changes.

`apiKey` and `appId` are per-app; `messagingSenderId`, `projectId` and
`storageBucket` are per-project. Values come from `google-services.json`
(Android) and `GoogleService-Info.plist` (iOS) — neither file is committed, the
defines replace them.

## Notes / prerequisites

- Flutter is pinned to **3.41.6** in all workflows — bump in one place per file if you upgrade.
- `build_runner` is intentionally not used: this project has no code generation.
- iOS release runs on `macos-14`; Android and CI run on `ubuntu-latest`.
- Secrets files (keystore, `key.properties`, service-account JSON, `.p8`) are all git-ignored — see `.gitignore`.
