# shellcheck shell=sh
# Sourced by the root manager's module installer (Magisk, KernelSU or APatch),
# which provides MODPATH, ui_print, abort and set_perm_recursive.
# This script makes no network requests.

# shellcheck source=lib/common.sh
. "$MODPATH/lib/common.sh"

DEVICE=$(zf_device)
if [ "$DEVICE" != "$ZF_SUPPORTED_DEVICE" ]; then
  ui_print "! ZUXFree supports the Legion Y700 Gen 4 ($ZF_SUPPORTED_DEVICE) only."
  ui_print "! This device reports: ${DEVICE:-unknown}"
  abort "! Aborting."
fi

case "$(zf_sdk_status)" in
  tested)
    ui_print "- Legion Y700 Gen 4, Android 16"
    ;;
  untested)
    ui_print "- Legion Y700 Gen 4, Android 17"
    ui_print "! Android 17 support is untested. Missing apps are skipped,"
    ui_print "! and everything is undone if you remove the module."
    ;;
  *)
    ui_print "! Unsupported Android version (SDK $(getprop ro.build.version.sdk))."
    abort "! Aborting."
    ;;
esac

mkdir -p "$ZF_DATA"
if [ -f "$ZF_CONFIG" ]; then
  ui_print "- Keeping your settings: $ZF_CONFIG"
else
  cp "$MODPATH/config.default.sh" "$ZF_CONFIG"
  ui_print "- Created settings file: $ZF_CONFIG"
fi
zf_load_config

ui_print "- Hiding China-only system apps..."
# shellcheck disable=SC2046  # split "<a> <b>" into $1 $2
set -- $(zf_apply_hides "$MODPATH" "$MODPATH/lists")
ui_print "  $1 hidden, $2 not present on this firmware"

ui_print "- Removing China-market apps for this user..."
removed=$(zf_debloat "$MODPATH/lists/remove-user.txt")
ui_print "  $removed removed (all restorable on uninstall)"

zf_log "installed $(grep '^version=' "$MODPATH/module.prop" | cut -d= -f2) on SDK $(getprop ro.build.version.sdk)"

ui_print "- Reboot to finish. Settings: $ZF_CONFIG"

set_perm_recursive "$MODPATH" 0 0 0755 0644
