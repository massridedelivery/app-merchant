# merchant_app

Merchant App

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## CI/CD

This project uses **GitHub Actions + Fastlane** to test every change and ship
signed builds to the **Google Play Store** and **Apple App Store / TestFlight**.
Full secret/setup details live in [`docs/CICD_SETUP.md`](docs/CICD_SETUP.md).

### When each workflow runs

| Workflow | File | Runs when | Result |
|----------|------|-----------|--------|
| **CI** | `.github/workflows/ci.yml` | every **pull request** and every **push to `main` / `develop`** | analyze + test + debug APK build (quality gate) |
| **Release Android** | `.github/workflows/release-android.yml` | push a **tag `v*`** (e.g. `v1.0.1`) **or** manual *Run workflow* | signed **AAB** uploaded to Google Play |
| **Release iOS** | `.github/workflows/release-ios.yml` | push a **tag `v*`** **or** manual *Run workflow* | signed **IPA** uploaded to TestFlight |

### The flow

```
                 ┌─────────────────────────────────────────────┐
  open PR  ─────▶│ CI: pub get → format(soft) → analyze → test  │
  push branch    │     → debug APK build                        │
                 └─────────────────────────────────────────────┘
                                     │  merge to main
                                     ▼
                 ┌─────────────────────────────────────────────┐
  git tag v1.0.1 │ Release Android          Release iOS         │
  git push --tags│  build signed AAB         build signed IPA   │
    (or manual)  │  Fastlane supply    ─┐   ┌─  Fastlane pilot  │
                 │  → Google Play        │   │   → TestFlight    │
                 └───────────────────────┴───┴──────────────────┘
```

**Day-to-day:**

1. Open a PR → **CI** runs automatically and must pass before merge.
2. Merge to `main`.
3. Cut a release:

   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

   This triggers **both** release workflows. You can also run either one on its
   own from the **Actions** tab via *Run workflow* (Android lets you pick the
   Play track: `internal` / `alpha` / `beta` / `production`).

> **Before releases work**, the signing/publishing **GitHub Secrets must be
> added** (see [`docs/CICD_SETUP.md`](docs/CICD_SETUP.md)) and iOS needs a **paid
> Apple Developer account** with a distribution-capable team. Until then, CI runs
> fine but the release jobs will fail at the signing/upload step.

### Environment config

Builds pass config via `--dart-define-from-file`:

- `env/dev.json` — used by CI / debug builds
- `env/prod.json` — used by release builds

> Note: these are currently scaffolds — the app still hardcodes the API base URL
> in `lib/core/network/api_client.dart`. Wire it to `String.fromEnvironment(...)`
> to make the env files take effect.
