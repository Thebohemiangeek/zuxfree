# Changelog

## v0.1.0 (pre-release, not yet tested on a device)

First release.

- Hides 13 China-only system apps systemlessly, including the Lenovo promo apps (`LenovoWhatsNew`, `TabletPushOut`) and cloud sync (`XuiEasySync`) that ZUI re-enables at every boot.
- Removes 20 China-market preinstalled apps for the main user, matched by exact package name.
- Re-checks on every boot and removes listed apps that came back after an OTA.
- Writes every removal to a ledger and reinstalls everything when the module is uninstalled.
- Keeps your settings in `/data/adb/zuxfree/config.sh` across updates: keep list, extra removals, optional tier, OTA block, branding, experimental region spoof.
- Adds an Action button that re-applies settings and shows a status summary.
- Makes no network requests during install and bundles no Lenovo or Google files.
- Supports Android 16 (SDK 36). Android 17 (SDK 37) installs with an "untested" warning.
