# shellcheck shell=sh
# shellcheck disable=SC2034  # ZUXFREE_* settings are read by the scripts that source this file
# Shared helpers for ZUXFree. Sourced by customize.sh, service.sh,
# post-fs-data.sh, action.sh and uninstall.sh.
#
# ZUXFREE_DATA and ZUXFREE_SYSROOT exist so the test suite can run these
# functions against a fake device; on a real device both keep their defaults.

ZF_DATA="${ZUXFREE_DATA:-/data/adb/zuxfree}"
ZF_SYSROOT="${ZUXFREE_SYSROOT:-}"
ZF_CONFIG="$ZF_DATA/config.sh"
ZF_LEDGER="$ZF_DATA/removed.list"
ZF_LOG="$ZF_DATA/zuxfree.log"
ZF_LOG_MAX_LINES=500

ZF_SUPPORTED_DEVICE="TB322FC"
ZF_SDK_TESTED="36"
ZF_SDK_UNTESTED="37"

zf_log() {
  mkdir -p "$ZF_DATA"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$ZF_LOG"
}

zf_trim_log() {
  [ -f "$ZF_LOG" ] || return 0
  if [ "$(wc -l < "$ZF_LOG")" -gt "$ZF_LOG_MAX_LINES" ]; then
    tail -n "$ZF_LOG_MAX_LINES" "$ZF_LOG" > "$ZF_LOG.tmp" && mv "$ZF_LOG.tmp" "$ZF_LOG"
  fi
}

# Print to the installer UI when running inside it, otherwise to stdout.
zf_say() {
  if command -v ui_print >/dev/null 2>&1; then ui_print "$*"; else echo "$*"; fi
}

zf_load_config() {
  # Defaults; config.sh overrides any of them.
  ZUXFREE_HIDE_OPTIONAL=0
  ZUXFREE_BLOCK_OTA=0
  ZUXFREE_BRANDING=1
  ZUXFREE_REGION_SPOOF=0
  ZUXFREE_REDEBLOAT_ON_BOOT=1
  ZUXFREE_KEEP=""
  ZUXFREE_EXTRA_REMOVE=""
  ZUXFREE_EXTRA_HIDE=""
  if [ -f "$ZF_CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$ZF_CONFIG"
  fi
}

zf_is_on() {
  case "$1" in 1|true|yes|on|TRUE|YES|ON) return 0 ;; esac
  return 1
}

# Print the first column of a list file, skipping comments and blank lines.
zf_read_list() {
  [ -f "$1" ] || return 0
  sed -e 's/#.*//' "$1" | awk 'NF { print $1 }'
}

# True if word $1 appears in the space-separated list $2.
zf_has_word() {
  case " $2 " in *" $1 "*) return 0 ;; esac
  return 1
}

# ---------------------------------------------------------------------------
# Device checks
# ---------------------------------------------------------------------------

zf_device() {
  d=$(getprop ro.product.vendor.device)
  [ -n "$d" ] || d=$(getprop ro.product.device)
  printf '%s' "$d"
}

# Prints "tested", "untested" or "unsupported".
zf_sdk_status() {
  case "$(getprop ro.build.version.sdk)" in
    "$ZF_SDK_TESTED") echo tested ;;
    "$ZF_SDK_UNTESTED") echo untested ;;
    *) echo unsupported ;;
  esac
}

# ---------------------------------------------------------------------------
# Systemless hiding of system apps
# ---------------------------------------------------------------------------

# Every path ZUXFree should hide under the current config, one per line.
zf_hide_targets() {
  lists="$1"
  zf_read_list "$lists/hide-default.txt"
  if zf_is_on "$ZUXFREE_HIDE_OPTIONAL"; then
    zf_read_list "$lists/hide-optional.txt"
  fi
  if zf_is_on "$ZUXFREE_BLOCK_OTA"; then
    zf_read_list "$lists/hide-ota.txt"
  fi
  for p in $ZUXFREE_EXTRA_HIDE; do echo "$p"; done
}

# Rebuild the module's system/ tree so each target directory is replaced by
# an empty one (".replace" marker, understood by Magisk, KernelSU and APatch).
# Targets missing on this firmware are skipped, so a list written for one
# build cannot break another. Prints "<hidden> <skipped>".
zf_apply_hides() {
  moddir="$1"
  lists="$2"
  rm -rf "$moddir/system"
  hidden=0
  skipped=0
  for path in $(zf_hide_targets "$lists"); do
    case "$path" in
      /system/*) ;;
      *) zf_log "ignored hide path outside /system: $path"; skipped=$((skipped + 1)); continue ;;
    esac
    if [ -d "$ZF_SYSROOT$path" ]; then
      mkdir -p "$moddir$path"
      : > "$moddir$path/.replace"
      hidden=$((hidden + 1))
    else
      zf_log "hide target not on this firmware: $path"
      skipped=$((skipped + 1))
    fi
  done
  echo "$hidden $skipped"
}

# ---------------------------------------------------------------------------
# Per-user removal of preinstalled apps, with a restore ledger
# ---------------------------------------------------------------------------

zf_installed_packages() {
  pm list packages --user 0 2>/dev/null | sed -e 's/^package://' | tr -d '\r'
}

# Ledger lines are "<package> <apk directory>" so apps that were fully
# removed can be reinstalled from their original location later.
zf_ledger_has() {
  [ -f "$ZF_LEDGER" ] && awk -v p="$1" '$1 == p { found = 1 } END { exit !found }' "$ZF_LEDGER"
}

zf_apk_dir() {
  first=$(pm path "$1" 2>/dev/null | head -n 1 | sed -e 's/^package://' | tr -d '\r')
  [ -n "$first" ] && dirname "$first"
}

# Remove every listed package that is installed for user 0 and not kept.
# Prints the number removed.
zf_debloat() {
  listfile="$1"
  installed=$(zf_installed_packages)
  removed=0
  for pkg in $(zf_read_list "$listfile") $ZUXFREE_EXTRA_REMOVE; do
    zf_has_word "$pkg" "$ZUXFREE_KEEP" && continue
    printf '%s\n' "$installed" | grep -qxF "$pkg" || continue
    dir=$(zf_apk_dir "$pkg")
    if pm uninstall --user 0 "$pkg" >/dev/null 2>&1; then
      zf_ledger_has "$pkg" || printf '%s %s\n' "$pkg" "${dir:--}" >> "$ZF_LEDGER"
      zf_log "removed $pkg"
      removed=$((removed + 1))
    else
      zf_log "could not remove $pkg"
    fi
  done
  echo "$removed"
}

# Bring back everything in the ledger. Prints "<restored> <failed>".
zf_restore() {
  restored=0
  failed=0
  if [ -f "$ZF_LEDGER" ]; then
    while read -r pkg dir; do
      [ -n "$pkg" ] || continue
      if cmd package install-existing --user 0 "$pkg" >/dev/null 2>&1; then
        ok=1
      elif [ -n "$dir" ] && [ "$dir" != "-" ] && ls "$ZF_SYSROOT$dir"/*.apk >/dev/null 2>&1; then
        # shellcheck disable=SC2046
        if pm install -r --user 0 $(ls "$ZF_SYSROOT$dir"/*.apk) >/dev/null 2>&1; then ok=1; else ok=0; fi
      else
        ok=0
      fi
      if [ "$ok" = 1 ]; then
        zf_log "restored $pkg"
        restored=$((restored + 1))
      else
        zf_log "could not restore $pkg"
        failed=$((failed + 1))
      fi
    done < "$ZF_LEDGER"
    rm -f "$ZF_LEDGER"
  fi
  echo "$restored $failed"
}

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

# Apply a props file ("key=value" lines) with resetprop.
zf_apply_props() {
  [ -f "$1" ] || return 0
  sed -e 's/#.*//' "$1" | while IFS='=' read -r key value; do
    [ -n "$key" ] || continue
    resetprop -n "$key" "$value"
  done
}

zf_wait_for_boot() {
  i=0
  while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 180 ]; do
    sleep 2
    i=$((i + 1))
  done
}

# Show a one-line status in the root manager's module list.
zf_set_description() {
  prop="$1/module.prop"
  [ -f "$prop" ] || return 0
  sed -i "s|^description=.*|description=$2|" "$prop"
}
