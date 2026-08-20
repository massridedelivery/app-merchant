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
| **Release Android** | `.github/workflows/release-android.yml` | **push to `main`** → `internal`; **tag `v*`** → `production`; **manual** → chosen track | signed **AAB** uploaded to Google Play |
| **Release iOS** | `.github/workflows/release-ios.yml` | **push to `main`**, **tag `v*`**, or **manual** | signed **IPA** uploaded to TestFlight |

Releases are **automatic on merge to `main`**, but only to **testing channels**
(Play `internal` track + TestFlight). Promotion to the **production** Play track
happens on a `v*` tag or a manual run — production is never auto-published.
Each build uses the workflow run number as its build number so every store
upload has a unique, increasing version.

### The flow

```
                 ┌─────────────────────────────────────────────┐
  open PR  ─────▶│ CI: pub get → format(soft) → analyze → test  │
  push branch    │     → debug APK build                        │
                 └─────────────────────────────────────────────┘
                                     │  merge to main
                                     ▼   (automatic)
                 ┌─────────────────────────────────────────────┐
                 │ Release Android           Release iOS        │
                 │  build signed AAB          build signed IPA  │
                 │  Fastlane supply     ─┐   ┌─ Fastlane pilot  │
                 │  → Play **internal**  │   │  → **TestFlight** │
                 └───────────────────────┴───┴──────────────────┘
                                     │  git tag v1.0.1 (or manual)
                                     ▼
                        Android → Play **production**
```

**Day-to-day:**

1. Open a PR → **CI** runs automatically and must pass before merge.
2. **Merge to `main`** → Android + iOS release workflows run automatically and
   ship to Play `internal` and TestFlight. No manual step needed.
3. Promote to production when ready:

   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

   The Android workflow then uploads to the `production` track. You can also run
   either release from the **Actions** tab via *Run workflow* (Android lets you
   pick the track: `internal` / `alpha` / `beta` / `production`).

> **Before releases work**, the signing/publishing **GitHub Secrets must be
> added** (see [`docs/CICD_SETUP.md`](docs/CICD_SETUP.md)) and iOS needs a **paid
> Apple Developer account** with a distribution-capable team. Until then, CI runs
> fine but the release jobs will fail at the signing/upload step.

### Environment config

Builds pass config via `--dart-define-from-file`:

- `env/dev.json` — used by CI / debug builds
- `env/prod.json` — used by release builds

`ApiClient.baseUrl`, `ApiClient.useMock` and `SocketService.wsUrl` read these
through `String.fromEnvironment`, so a build with no env file falls back to the
in-app mock against `localhost:8080`.

`env/dev.json` carries real Firebase credentials for the `dev-merchant-4619a`
project, so debug builds have working push. The same keys in `env/prod.json`
are intentionally blank — push stays off until a production Firebase project
exists, and a placeholder value there would crash iOS at launch rather than
disable push. See [`docs/CICD_SETUP.md`](docs/CICD_SETUP.md).

> **`env/prod.json` currently points at the dev host on purpose.** There is no
> production backend yet, and nothing in CI overrides the file, so release
> builds for both stores ship against `driver-api-dev.nutchaphut.dev`. Change
> the two URLs in that file the day a production host exists — the release
> workflows need no edit.
