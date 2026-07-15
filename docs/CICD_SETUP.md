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
| `.github/workflows/release-android.yml` | tag `v*` or manual | builds a **signed AAB** and uploads to Google Play (default track: `internal`) |
| `.github/workflows/release-ios.yml` | tag `v*` or manual | builds a **signed IPA** and uploads to **TestFlight** |

Cutting a release:

```bash
git tag v1.0.1
git push origin v1.0.1
```

…or run either release workflow manually from the Actions tab.

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
`--dart-define-from-file`. **Note:** the app code does not yet read these values —
the API base URL is currently hardcoded in
`lib/core/network/api_client.dart` (`http://localhost:8080/api/food`) and the
socket URL in `lib/core/services/socket_service.dart`. To make the env files
effective, switch those to:

```dart
static const String baseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080/api/food');
```

Until then the env files exist only to satisfy the build flag.

## Notes / prerequisites

- Flutter is pinned to **3.41.6** in all workflows — bump in one place per file if you upgrade.
- `build_runner` is intentionally not used: this project has no code generation.
- iOS release runs on `macos-14`; Android and CI run on `ubuntu-latest`.
- Secrets files (keystore, `key.properties`, service-account JSON, `.p8`) are all git-ignored — see `.gitignore`.
