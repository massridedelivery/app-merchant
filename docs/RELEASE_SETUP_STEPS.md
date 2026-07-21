# Release Setup Runbook — Google Play & Apple App Store

Step-by-step guide to make the CI/CD pipeline actually deploy. The pipeline
(GitHub Actions workflows + Fastlane) is already in the repo — this runbook
covers the **store accounts + secrets** you must set up by hand.

For the secret reference table see [`CICD_SETUP.md`](CICD_SETUP.md); for how the
workflows trigger see the CI/CD section of the [root README](../README.md).

> **Why this is manual:** it involves paid developer accounts, signing keys, and
> credentials that must be created and held by the app owner — they can't be
> automated or handled by a third party.

---

## 🟢 Part A — Google Play (Android)

### A1. Create a Google Play Developer account
- Go to [play.google.com/console](https://play.google.com/console) → pay the
  **one-time $25** fee → complete identity verification (can take 1–2 days).

### A2. Create the app in Play Console
- Create app → set name, type (App), language.
- The **package name must match** `com.mass.merchant_app`.

### A3. Generate the upload keystore (locally)
```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
> Keep the `.jks` file and passwords safe — **if lost you can't update the app**.
> Never commit it (already git-ignored).

### A4. Upload the first AAB manually (required)
The Play API can only push once the app has at least one release:
```bash
flutter build appbundle --release
```
Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console →
Internal testing → Create release (once, by hand). Enable **Play App Signing**.

### A5. Create a service account (for automated uploads)
1. Play Console → **Setup → API access** → link a Google Cloud project.
2. In Google Cloud → create a Service Account → create a **JSON key** → download.
3. Back in Play Console → **Users & permissions** → invite that service-account
   email → grant it the **Release** permission (release to testing/production).

### A6. Prepare the secret values (base64)
```bash
base64 -i upload-keystore.jks | pbcopy          # → ANDROID_KEYSTORE_BASE64
base64 -i play-service-account.json | pbcopy    # → PLAY_SERVICE_ACCOUNT_JSON
```

---

## 🍎 Part B — Apple App Store (iOS)

### B1. Join the Apple Developer Program
- [developer.apple.com/programs](https://developer.apple.com/programs) → **$99/year**.
- ⚠️ The project currently uses the **personal team `BPC676HCRQ`**, which
  **cannot publish to the App Store**. You must switch to the paid team.

### B2. Update the Team ID in the project
Replace `BPC676HCRQ` with the new 10-character Team ID in:
- `ios/ExportOptions.plist` (the `teamID` key)
- `ios/Runner.xcodeproj` — open in Xcode → Signing & Capabilities → select the new team.

### B3. Create the app in App Store Connect
- [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Apps → **+** →
  Bundle ID = `com.mass.merchantApp` (create the App ID in the Developer portal
  first if it doesn't exist).

### B4. Create an App Store Connect API key
- App Store Connect → **Users and Access → Integrations → App Store Connect API**.
- Create a key with the **App Manager** role → download `AuthKey_XXXX.p8`
  (**downloadable only once**).
- Note the **Key ID** and **Issuer ID**.

### B5. Set up fastlane match (stores certs for CI)
Create an empty **private git repo** (e.g. `massridedelivery/certificates`),
then run once on a Mac:
```bash
cd ios
bundle install
bundle exec fastlane ios certificates   # creates the distribution cert + profile and pushes them to the match repo
```
> You'll set a `MATCH_PASSWORD` (encryption passphrase) — record it.

### B6. Prepare the secret values (base64)
```bash
base64 -i AuthKey_XXXX.p8 | pbcopy                # → APP_STORE_CONNECT_API_KEY_BASE64
echo -n "GIT_USER:GIT_TOKEN" | base64 | pbcopy    # → MATCH_GIT_BASIC_AUTHORIZATION
```

---

## 🔐 Part C — Add secrets to GitHub & test

### C1. Add the secrets (requires admin on the repo)
Use the `gh` CLI (or Settings → Secrets and variables → Actions):
```bash
R=massridedelivery/app-merchant

# Android
gh secret set ANDROID_KEYSTORE_BASE64      --repo $R < <(base64 -i upload-keystore.jks)
gh secret set ANDROID_KEYSTORE_PASSWORD    --repo $R
gh secret set ANDROID_KEY_ALIAS            --repo $R   # value: upload
gh secret set ANDROID_KEY_PASSWORD         --repo $R
gh secret set PLAY_SERVICE_ACCOUNT_JSON    --repo $R < <(base64 -i play-service-account.json)

# iOS
gh secret set APP_STORE_CONNECT_KEY_ID           --repo $R
gh secret set APP_STORE_CONNECT_ISSUER_ID        --repo $R
gh secret set APP_STORE_CONNECT_API_KEY_BASE64   --repo $R < <(base64 -i AuthKey_XXXX.p8)
gh secret set MATCH_GIT_URL                      --repo $R   # match repo URL
gh secret set MATCH_PASSWORD                     --repo $R
gh secret set MATCH_GIT_BASIC_AUTHORIZATION      --repo $R
```
(Commands without `<` prompt for the value with hidden input.)

### C2. Verify all secrets are set
```bash
gh secret list --repo massridedelivery/app-merchant
```
You should see all **11** (5 Android + 6 iOS).

### C3. Test
- **Test Android first** (simpler, no Apple wait): Actions → *Release Android* →
  Run workflow → track `internal` → confirm it lands on the Play internal track.
- Then **merge to `main`** → both Android + iOS auto-release to internal/TestFlight.

---

## Recommended order

| Step | Do this | Time |
|------|---------|------|
| 1 | Merge the CI/CD PR (get the pipeline onto `main`) | now |
| 2 | Google Play: A1–A6 | 1–2 days (account approval) |
| 3 | Add Android secrets + test Run workflow | ~30 min |
| 4 | Apple: B1–B6 | ~1 day |
| 5 | Add iOS secrets + test | ~30 min |

## Status: done vs. to-do

- ✅ **Done (in repo):** workflows, Fastlane lanes, Android signing config,
  build-number wiring, auto-release logic, docs.
- ⬜ **To do (manual):** both store accounts, keystore/API keys, the 11 secrets,
  and updating the Apple Team ID.
