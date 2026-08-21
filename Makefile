# Merchant App — developer tasks.
#
# Every target that builds or runs the app injects config through
# --dart-define-from-file. Override the file per invocation:
#
#     make run ENV_FILE=env/prod.json
#     make run DEVICE=chrome
#
# Run `make` on its own for the target list.

ENV_FILE ?= env/dev.json
DEVICE   ?=

DEFINES  := --dart-define-from-file=$(ENV_FILE)
DEVICE_ARG = $(if $(DEVICE),-d $(DEVICE),)

.DEFAULT_GOAL := help

.PHONY: help deps upgrade outdated run run-mock run-web \
        analyze format format-check test test-coverage ci \
        apk apk-release appbundle ipa web clean \
        bump_build deploy_dev

help:
	@echo "Merchant App - make targets"
	@echo ""
	@echo "  Setup"
	@echo "    deps           flutter pub get"
	@echo "    upgrade        flutter pub upgrade"
	@echo "    outdated       list dependencies with newer versions"
	@echo ""
	@echo "  Run"
	@echo "    run            run on the default device with $(ENV_FILE)"
	@echo "    run-mock       same, but force the in-app mock API"
	@echo "    run-web        run a web-server build on port 8085"
	@echo ""
	@echo "  Quality"
	@echo "    analyze        static analysis, same flags as CI"
	@echo "    format         rewrite sources with dart format"
	@echo "    format-check   fail if anything is unformatted"
	@echo "    test           run the test suite"
	@echo "    test-coverage  run tests and write coverage/lcov.info"
	@echo "    ci             the gates CI enforces: deps, analyze, test"
	@echo ""
	@echo "  Build"
	@echo "    apk            debug APK, the CI per-PR sanity build"
	@echo "    apk-release    release APK"
	@echo "    appbundle      release AAB for Play, built from env/prod.json"
	@echo "    ipa            release IPA"
	@echo "    web            release web bundle"
	@echo "    clean          flutter clean"
	@echo ""
	@echo "  Release"
	@echo "    bump_build     bump the +N build number in pubspec.yaml"
	@echo "    deploy_dev     bump, build and upload a dev IPA to TestFlight"
	@echo ""
	@echo "  Variables"
	@echo "    ENV_FILE       dart-define file, currently $(ENV_FILE)"
	@echo "    DEVICE         device id passed to flutter run"

# ─── Setup ──────────────────────────────────────────────────────────────────

deps:
	flutter pub get

upgrade:
	flutter pub upgrade

outdated:
	flutter pub outdated

# ─── Run ────────────────────────────────────────────────────────────────────

run:
	flutter run $(DEVICE_ARG) $(DEFINES)

# --dart-define is appended after the defines read from the file, and the last
# value for a key wins, so this overrides USE_MOCK without a second env file.
run-mock:
	flutter run $(DEVICE_ARG) $(DEFINES) --dart-define=USE_MOCK=true

# Matches the merchant-app-web entry in .claude/launch.json.
run-web:
	flutter run -d web-server --web-hostname localhost --web-port 8085 $(DEFINES)

# ─── Quality ────────────────────────────────────────────────────────────────

# --no-fatal-infos mirrors CI: warnings and errors fail, infos do not. The
# codebase still reports infos, so a bare `flutter analyze` would always fail.
analyze:
	flutter analyze --no-fatal-infos

format:
	dart format .

format-check:
	dart format --output=none --set-exit-if-changed .

test:
	flutter test --reporter expanded

test-coverage:
	flutter test --coverage

# The hard gates from .github/workflows/ci.yml. Formatting is deliberately not
# included: CI runs it with continue-on-error because the codebase has never
# been formatted in full. Run `make format-check` to see that drift.
ci: deps analyze test

# ─── Build ──────────────────────────────────────────────────────────────────

apk:
	flutter build apk --debug $(DEFINES)

apk-release:
	flutter build apk --release $(DEFINES)

# Play uploads always ship prod config regardless of ENV_FILE.
appbundle:
	flutter build appbundle --release --dart-define-from-file=env/prod.json

ipa:
	flutter build ipa --release $(DEFINES)

web:
	flutter build web --release $(DEFINES)

clean:
	flutter clean

# ─── Release ────────────────────────────────────────────────────────────────

# Bump the build number (the +N in pubspec.yaml). deploy_dev does this for you;
# use this target to bump on its own.
bump_build:
	@bash tool/bump_build.sh

# Bump the build number, then build a Release IPA under the .dev bundle id and
# upload it to TestFlight (MassMerchantDev / com.mass.merchantApp.dev). Requires
# the App Store Connect credentials described in tool/deploy_dev.sh.
deploy_dev:
	@bash tool/deploy_dev.sh
