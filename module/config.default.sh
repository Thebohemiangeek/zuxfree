# shellcheck disable=SC2034  # settings are read by the scripts that source this file
# ZUXFree settings. This file is copied to /data/adb/zuxfree/config.sh on
# first install and is never overwritten by updates. After editing it, run the
# module's Action button (or reboot) to apply.

# Also hide the optional system apps in lists/hide-optional.txt
# (live captions, AI Lens, OAID service, PRC setup steps). 0 = off, 1 = on.
ZUXFREE_HIDE_OPTIONAL=0

# Hide the Lenovo updater so an OTA cannot replace your rooted system.
ZUXFREE_BLOCK_OTA=0

# English device naming, and turn off the China web filter / education limits.
ZUXFREE_BRANDING=1

# Experimental: report the region as global (ROW) instead of PRC.
ZUXFREE_REGION_SPOOF=0

# Re-check on every boot and remove listed apps that came back (e.g. after an OTA).
ZUXFREE_REDEBLOAT_ON_BOOT=1

# Space-separated packages from lists/remove-user.txt that you want to keep.
# Example: ZUXFREE_KEEP="com.lemon.lv com.lenovo.club.app"
ZUXFREE_KEEP=""

# Extra packages to remove for the main user (exact names, space-separated).
ZUXFREE_EXTRA_REMOVE=""

# Extra system app directories to hide (must start with /system/).
# Example: ZUXFREE_EXTRA_HIDE="/system/priv-app/ZuiAIService"
ZUXFREE_EXTRA_HIDE=""
