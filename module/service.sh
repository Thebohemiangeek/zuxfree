#!/system/bin/sh
# Runs after boot: re-remove listed apps that came back (OTA, ZUI restores)
# and show a status line in the root manager.
MODDIR=${0%/*}
# shellcheck source=lib/common.sh
. "$MODDIR/lib/common.sh"

zf_wait_for_boot
# Give ZUI's own boot-time package restore a head start so we run after it.
sleep 20

zf_load_config
removed=0
if zf_is_on "$ZUXFREE_REDEBLOAT_ON_BOOT"; then
  removed=$(zf_debloat "$MODDIR/lists/remove-user.txt")
fi

hidden=$(find "$MODDIR/system" -name .replace 2>/dev/null | wc -l | tr -d ' ')
ledger=0
[ -f "$ZF_LEDGER" ] && ledger=$(wc -l < "$ZF_LEDGER" | tr -d ' ')

status="Active: $hidden system apps hidden, $ledger apps removed"
[ "$removed" -gt 0 ] 2>/dev/null && status="$status ($removed re-removed this boot)"
zf_set_description "$MODDIR" "$status"
zf_log "boot: $status"
zf_trim_log
