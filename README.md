# ZUXFree

A root module that strips the China-only parts out of ZUXOS on the **Lenovo Legion Y700 Gen 4 (TB322FC)**, without bundling any firmware files and with a clean undo.

> **Status: v0.1.0 pre-release.** The logic is covered by an automated test suite that simulates the device, but it has **not yet been run on a real tablet**. Install it only if you can recover your device (stock firmware + EDL), and please report what happens.

## What it does

| | |
|---|---|
| **Hides China-only system apps** | Baidu location, Lenovo China cloud sync, Lenovo promo pop-ups and push service, the Xiaotian voice assistant, the ZUI China browser, the carrier data monitor, the ZUI log uploader and others ([full list](module/lists/hide-default.txt)). ZUI turns these back on at every boot, so `pm uninstall`/`disable` from adb doesn't stick. A systemless overlay does. |
| **Removes China-market apps** | Sogou keyboard, CapCut China, the Lenovo China app store, Douyin, Kuaishou, iQIYI and more ([full list](module/lists/remove-user.txt)), matched by **exact** package name. |
| **Survives OTAs** | On every boot it checks for listed apps that came back and removes them again. |
| **Fully reversible** | Every removal is recorded. Uninstalling the module brings everything back, including apps that live in `/system/preinstall`. |
| **Configurable** | Keep apps, remove extra ones, hide more, block the Lenovo updater, all from one settings file that updates never overwrite. |
| **Safe by construction** | No network access during install, no bundled Lenovo/Google APKs, and list entries missing on your firmware are skipped instead of failing. |

It does **not** touch Google services, Play Integrity, Widevine or the bootloader. Whether Netflix HD keeps working depends on how you rooted, not on this module.

## Requirements

- Legion Y700 Gen 4, **TB322FC**
- ZUXOS 1.5 (Android 16). Android 17 (ZUXOS 2.5) installs with an "untested" warning.
- Root with **Magisk**, **KernelSU** or **APatch** (on build 1.5.10.259 and later this currently means LTBox plus the community ABL patch; see the XDA Gen 4 threads)

## Install

1. Download `zuxfree-vX.Y.Z.zip` from [Releases](../../releases) and check it against the `.sha256` file next to it.
2. Install the zip from your root manager.
3. Reboot.

The module card then shows a status line such as `Active: 13 system apps hidden, 6 apps removed`.

## Settings

Edit `/data/adb/zuxfree/config.sh`, then press the module's **Action** button (or reboot):

| Setting | Default | Effect |
|---|---|---|
| `ZUXFREE_KEEP` | empty | Packages from the removal list you want to keep, e.g. `"com.lemon.lv"` |
| `ZUXFREE_EXTRA_REMOVE` | empty | More packages to remove for the user |
| `ZUXFREE_EXTRA_HIDE` | empty | More system app folders to hide (must start with `/system/`) |
| `ZUXFREE_HIDE_OPTIONAL` | `0` | Also hide [live captions, AI Lens, the OAID service and the PRC setup steps](module/lists/hide-optional.txt) |
| `ZUXFREE_BLOCK_OTA` | `0` | Hide the Lenovo updater so an OTA can't replace your rooted system |
| `ZUXFREE_BRANDING` | `1` | English device name; turn off the China web filter and education limits |
| `ZUXFREE_REGION_SPOOF` | `0` | Experimental: report the region as global (ROW) |
| `ZUXFREE_REDEBLOAT_ON_BOOT` | `1` | Re-remove listed apps that came back |

The log is at `/data/adb/zuxfree/zuxfree.log`.

## Uninstall

Remove the module in your root manager and reboot. Hidden system apps come back immediately. Removed apps are reinstalled about 30 seconds after boot.

## Development

```sh
bash tests/run.sh     # simulated-device test suite
bash tools/build.sh   # builds dist/zuxfree-<version>.zip + .sha256 + update.json
```

CI runs ShellCheck, the tests and the build on every push. Tagging `vX.Y.Z` publishes a release.

**Adding an app:** read its folder with `adb shell pm path <package>`, add a line to the matching file in `module/lists/` with what it is, and add a test if the behaviour is new.

## Credits

This module was inspired by [DeZUX](https://gitlab.com/jjhitel/DeZUX) by miner7222, which showed what a "global" ZUXOS can look like. ZUXFree is a separate implementation written from scratch and shares no code with it. The package paths and properties were read from a stock TB322FC.

Not affiliated with Lenovo. Use at your own risk.

## License

[MIT](LICENSE)
