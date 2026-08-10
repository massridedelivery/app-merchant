# Merchant App — developer tasks
.PHONY: deploy_dev

# Build a Release IPA under the .dev bundle id and upload it to TestFlight
# (MassMerchantDev / com.mass.merchantApp.dev). Requires the App Store Connect
# credentials described in tool/deploy_dev.sh.
deploy_dev:
	@bash tool/deploy_dev.sh
