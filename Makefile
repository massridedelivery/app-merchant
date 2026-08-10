# Merchant App — developer tasks
.PHONY: deploy_dev bump_build

# Bump the build number (the +N in pubspec.yaml). deploy_dev does this for you;
# use this target to bump on its own.
bump_build:
	@bash tool/bump_build.sh

# Bump the build number, then build a Release IPA under the .dev bundle id and
# upload it to TestFlight (MassMerchantDev / com.mass.merchantApp.dev). Requires
# the App Store Connect credentials described in tool/deploy_dev.sh.
deploy_dev:
	@bash tool/deploy_dev.sh
