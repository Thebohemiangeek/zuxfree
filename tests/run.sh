#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2030,SC2031,SC2329  # check() takes single-quoted expressions; helpers run in subshells
# Runs ZUXFree's scripts against a simulated device: fake pm/cmd/getprop/
# resetprop binaries backed by files in a temp "device" directory.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MODSRC="$ROOT/module"
PASS=0
FAIL=0

# --------------------------------------------------------------------------
# Fake device
# --------------------------------------------------------------------------

new_device() {
  T=$(mktemp -d)
  export STATE="$T/state" ZUXFREE_SYSROOT="$T/sysroot" ZUXFREE_DATA="$T/data"
  MODPATH="$T/modules/zuxfree"
  mkdir -p "$STATE" "$ZUXFREE_SYSROOT" "$T/bin" "$T/modules"
  cp -r "$MODSRC" "$MODPATH"
  : > "$STATE/installed"; : > "$STATE/system_pkgs"; : > "$STATE/paths"; : > "$STATE/calls"
  printf 'ro.product.vendor.device=TB322FC\nro.build.version.sdk=36\nsys.boot_completed=1\n' > "$STATE/props"

  cat > "$T/bin/getprop" <<'EOF'
#!/usr/bin/env bash
awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$STATE/props"
EOF
  cat > "$T/bin/resetprop" <<'EOF'
#!/usr/bin/env bash
echo "resetprop $*" >> "$STATE/calls"
EOF
  cat > "$T/bin/pm" <<'EOF'
#!/usr/bin/env bash
echo "pm $*" >> "$STATE/calls"
case "$1" in
  list) sed 's/^/package:/' "$STATE/installed" ;;
  path) awk -v p="$2" '$1 == p { print "package:" $2 }' "$STATE/paths" ;;
  uninstall)
    pkg="${@: -1}"
    if grep -qxF "$pkg" "$STATE/installed"; then
      grep -vxF "$pkg" "$STATE/installed" > "$STATE/i.tmp"; mv "$STATE/i.tmp" "$STATE/installed"; echo Success
    else echo "Failure [not installed for 0]"; exit 1; fi ;;
  install)
    apk="${@: -1}"
    pkg=$(awk -v a="$apk" 'substr(a, length(a) - length($2) + 1) == $2 { print $1; exit }' "$STATE/paths")
    [ -n "$pkg" ] || { echo "Failure [unknown apk]"; exit 1; }
    echo "$pkg" >> "$STATE/installed"; echo Success ;;
esac
EOF
  cat > "$T/bin/cmd" <<'EOF'
#!/usr/bin/env bash
echo "cmd $*" >> "$STATE/calls"
if [ "$1 $2" = "package install-existing" ]; then
  pkg="${@: -1}"
  # Only system apps survive a per-user uninstall.
  if grep -qxF "$pkg" "$STATE/system_pkgs"; then echo "$pkg" >> "$STATE/installed"; exit 0; fi
  exit 1
fi
EOF
  cat > "$T/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$T/bin/"*
  export PATH="$T/bin:$PATH"
}

install_pkg()   { echo "$1" >> "$STATE/installed"; }
system_pkg()    { install_pkg "$1"; echo "$1" >> "$STATE/system_pkgs"; }
set_prop()      { grep -v "^$1=" "$STATE/props" > "$STATE/p.tmp"; echo "$1=$2" >> "$STATE/p.tmp"; mv "$STATE/p.tmp" "$STATE/props"; }
sys_dir()       { mkdir -p "$ZUXFREE_SYSROOT$1"; }
is_installed()  { grep -qxF "$1" "$STATE/installed"; }

# Run customize.sh the way a root manager does: sourced, with its helpers.
run_install() {
  (
    ui_print() { echo "$*"; }
    abort() { echo "$*"; exit 1; }
    set_perm_recursive() { :; }
    # shellcheck disable=SC1091
    . "$MODPATH/customize.sh"
  ) > "$STATE/install.out" 2>&1
}

# --------------------------------------------------------------------------
# Assertions
# --------------------------------------------------------------------------

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; [ -f "$STATE/install.out" ] && sed 's/^/       | /' "$STATE/install.out"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# --------------------------------------------------------------------------
# Tests
# --------------------------------------------------------------------------

echo "device and Android version gate"
new_device; set_prop ro.product.vendor.device TB321FC
run_install; check "refuses another Legion model" '[ $? -ne 0 ] && grep -q "TB322FC" "$STATE/install.out"'
new_device; set_prop ro.build.version.sdk 35
run_install; check "refuses Android 15" '[ $? -ne 0 ] && grep -q "Unsupported Android" "$STATE/install.out"'
new_device; set_prop ro.build.version.sdk 37
run_install; check "installs on Android 17 with an untested warning" '[ $? -eq 0 ] && grep -q "untested" "$STATE/install.out"'
new_device
run_install; check "installs on Android 16" '[ $? -eq 0 ]'
check "makes no network requests" '! grep -Eq "curl|wget|http" "$MODPATH/customize.sh"'

echo "hiding system apps"
new_device
sys_dir /system/priv-app/TabletPushOut
sys_dir /system/priv-app/LenovoWhatsNew
sys_dir /system/product/app/xiangbb
sys_dir /system/priv-app/LeVoiceCaptionApp
sys_dir /system/priv-app/LenovoOTA
run_install
check "hides promo apps DeZUX missed" '[ -f "$MODPATH/system/priv-app/TabletPushOut/.replace" ] && [ -f "$MODPATH/system/priv-app/LenovoWhatsNew/.replace" ]'
check "hides /product apps via /system/product" '[ -f "$MODPATH/system/product/app/xiangbb/.replace" ]'
check "skips targets missing on this firmware" '[ ! -e "$MODPATH/system/priv-app/BaiduNetworkLocation" ]'
check "leaves optional apps alone by default" '[ ! -e "$MODPATH/system/priv-app/LeVoiceCaptionApp" ]'
check "leaves the OTA updater alone by default" '[ ! -e "$MODPATH/system/priv-app/LenovoOTA" ]'
printf 'ZUXFREE_HIDE_OPTIONAL=1\nZUXFREE_BLOCK_OTA=1\nZUXFREE_EXTRA_HIDE="/vendor/app/X /system/priv-app/TabletUE"\n' >> "$ZUXFREE_DATA/config.sh"
sys_dir /system/priv-app/TabletUE
run_install
check "optional tier follows the config" '[ -f "$MODPATH/system/priv-app/LeVoiceCaptionApp/.replace" ]'
check "OTA block follows the config" '[ -f "$MODPATH/system/priv-app/LenovoOTA/.replace" ]'
check "extra hide paths are honoured" '[ -f "$MODPATH/system/priv-app/TabletUE/.replace" ]'
check "extra hide paths outside /system are refused" '[ ! -e "$MODPATH/vendor" ]'
printf 'ZUXFREE_HIDE_OPTIONAL=0\nZUXFREE_BLOCK_OTA=0\nZUXFREE_EXTRA_HIDE=""\n' >> "$ZUXFREE_DATA/config.sh"
(cd "$MODPATH" && sh ./action.sh >/dev/null)
check "action button rebuilds hides from the config" '[ ! -e "$MODPATH/system/priv-app/LenovoOTA" ] && [ -f "$MODPATH/system/priv-app/TabletPushOut/.replace" ]'

echo "removing apps for the user"
new_device
install_pkg com.lemon.lv
install_pkg com.lemon.lv.helper
install_pkg com.sohu.inputmethod.sogou.oem
install_pkg com.lenovo.legionzone
install_pkg com.lenovo.club.app
echo "com.lemon.lv /system/preinstall/Capcut_prc/base.apk" >> "$STATE/paths"
mkdir -p "$ZUXFREE_DATA"; cp "$MODSRC/config.default.sh" "$ZUXFREE_DATA/config.sh"
echo 'ZUXFREE_KEEP="com.lenovo.club.app"' >> "$ZUXFREE_DATA/config.sh"
run_install
check "removes listed apps" '! is_installed com.lemon.lv && ! is_installed com.sohu.inputmethod.sogou.oem'
check "exact names only (similar package untouched)" 'is_installed com.lemon.lv.helper'
check "keeps apps in ZUXFREE_KEEP" 'is_installed com.lenovo.club.app'
check "keeps Legion Zone (not on the list)" 'is_installed com.lenovo.legionzone'
check "records removals with their APK folder" 'grep -qx "com.lemon.lv /system/preinstall/Capcut_prc" "$ZUXFREE_DATA/removed.list"'
check "keeps existing settings on update" 'grep -q "com.lenovo.club.app" "$ZUXFREE_DATA/config.sh"'

new_device
install_pkg com.ss.android.ugc.aweme.lite
run_install
check "never touches a package that only shares a prefix" '! grep -q "uninstall --user 0 com.ss.android.ugc.aweme$" "$STATE/calls" && is_installed com.ss.android.ugc.aweme.lite'

echo "boot-time re-check"
install_pkg com.lemon.lv
(cd "$MODPATH" && sh ./service.sh)
check "removes an app that came back after an OTA" '! is_installed com.lemon.lv'
check "ledger has no duplicates" '[ "$(grep -c "^com.lemon.lv " "$ZUXFREE_DATA/removed.list")" -eq 1 ]'
check "shows status in the root manager" 'grep -q "^description=Active:" "$MODPATH/module.prop"'
echo "ZUXFREE_REDEBLOAT_ON_BOOT=0" >> "$ZUXFREE_DATA/config.sh"
install_pkg com.lemon.lv
(cd "$MODPATH" && sh ./service.sh)
check "boot re-check can be turned off" 'is_installed com.lemon.lv'

echo "properties"
new_device
(cd "$MODPATH" && sh ./post-fs-data.sh)
check "applies branding by default" 'grep -q "resetprop -n ro.zui.software.weblimit false" "$STATE/calls"'
check "branding keeps spaces in values" 'grep -q "resetprop -n ro.zuk.product.market Legion Tab Y700" "$STATE/calls"'
check "does not spoof region by default" '! grep -q "lgsi.region" "$STATE/calls"'
mkdir -p "$ZUXFREE_DATA"; echo "ZUXFREE_REGION_SPOOF=1" > "$ZUXFREE_DATA/config.sh"
(cd "$MODPATH" && sh ./post-fs-data.sh)
check "region spoof follows the config" 'grep -q "resetprop -n ro.config.lgsi.region row" "$STATE/calls"'

echo "uninstall restores everything"
new_device
system_pkg com.lenovo.leos.appstore
install_pkg com.lemon.lv
echo "com.lemon.lv /system/preinstall/Capcut_prc/base.apk" >> "$STATE/paths"
mkdir -p "$ZUXFREE_SYSROOT/system/preinstall/Capcut_prc"; : > "$ZUXFREE_SYSROOT/system/preinstall/Capcut_prc/base.apk"
run_install
check "both apps removed first" '! is_installed com.lenovo.leos.appstore && ! is_installed com.lemon.lv'
(cd "$MODPATH" && sh ./uninstall.sh); wait
sleep 0; for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$ZUXFREE_DATA/removed.list" ] || break; /bin/sleep 0.2; done
check "system app restored with install-existing" 'is_installed com.lenovo.leos.appstore'
check "fully removed preinstall reinstalled from its APK" 'is_installed com.lemon.lv && grep -q "pm install -r --user 0" "$STATE/calls"'
check "ledger and settings cleared, log kept" '[ ! -f "$ZUXFREE_DATA/removed.list" ] && [ ! -f "$ZUXFREE_DATA/config.sh" ] && [ -f "$ZUXFREE_DATA/zuxfree.log" ]'

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
