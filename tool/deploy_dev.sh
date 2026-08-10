#!/usr/bin/env bash
#
# Build a Release IPA under the .dev bundle id and upload it to TestFlight
# (App Store Connect app "MassMerchantDev" / com.mass.merchantApp.dev).
#
# The repo's Release config carries the production bundle id
# (com.mass.merchantApp), but the only App Store Connect record so far is the
# .dev one. Until a proper dev flavor (or the prod app) exists, this script
# temporarily rewrites the Release bundle id to .dev for the build and always
# restores it afterwards, so the override never lands in a commit.
#
# One-time prerequisites:
#   * Apple Distribution certificate in the login keychain (team Q7742Z74Q3)
#   * App Store Connect API key .p8 at
#       ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
#   * Credentials available via the environment or ios/.appstore_connect.env:
#       APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID
#     (copy ios/.appstore_connect.env.example to get started)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROD_BUNDLE_ID="com.mass.merchantApp"
DEV_BUNDLE_ID="${DEV_BUNDLE_ID:-com.mass.merchantApp.dev}"
PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
ENV_FILE="ios/.appstore_connect.env"
DART_DEFINE="env/dev.json"

# --- credentials ------------------------------------------------------------
# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && . "$ENV_FILE"
: "${APP_STORE_CONNECT_KEY_ID:?set APP_STORE_CONNECT_KEY_ID (env or $ENV_FILE)}"
: "${APP_STORE_CONNECT_ISSUER_ID:?set APP_STORE_CONNECT_ISSUER_ID (env or $ENV_FILE)}"

# --- always restore the project file ---------------------------------------
BACKUP="$(mktemp)"
cp "$PBXPROJ" "$BACKUP"
restore() { cp "$BACKUP" "$PBXPROJ"; rm -f "$BACKUP"; }
trap restore EXIT

echo "==> Pointing Release bundle id at ${DEV_BUNDLE_ID}"
# Exact match on the prod id + trailing ';' so RunnerTests and the already-.dev
# Debug config are left untouched.
perl -0pi -e "s/PRODUCT_BUNDLE_IDENTIFIER = \Q${PROD_BUNDLE_ID}\E;/PRODUCT_BUNDLE_IDENTIFIER = ${DEV_BUNDLE_ID};/g" "$PBXPROJ"

echo "==> Building release IPA (${DART_DEFINE})"
flutter build ipa --release \
  --export-method app-store \
  --dart-define-from-file="${DART_DEFINE}"

IPA="$(ls -t build/ios/ipa/*.ipa | head -1)"
[ -n "$IPA" ] || { echo "ERROR: no .ipa produced"; exit 1; }

echo "==> Uploading ${IPA} to TestFlight"
xcrun altool --upload-app --type ios \
  -f "$IPA" \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

echo "==> Done. The build will appear under MassMerchantDev in App Store"
echo "    Connect once Apple finishes processing."
