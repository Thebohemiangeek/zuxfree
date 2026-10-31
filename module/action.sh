#!/system/bin/sh
# The module's Action button in Magisk / KernelSU / APatch: re-read the
# settings, rebuild the hide list, remove listed apps now, and report.
MODDIR=${0%/*}
# shellcheck source=lib/common.sh
. "$MODDIR/lib/common.sh"

zf_load_config
echo "ZUXFree: applying $ZF_CONFIG"

# shellcheck disable=SC2046  # split "<a> <b>" into $1 $2
set -- $(zf_apply_hides "$MODDIR" "$MODDIR/lists")
echo "- System apps to hide: $1 (missing on this firmware: $2)"

removed=$(zf_debloat "$MODDIR/lists/remove-user.txt")
echo "- Apps removed now: $removed"

ledger=0
[ -f "$ZF_LEDGER" ] && ledger=$(wc -l < "$ZF_LEDGER" | tr -d ' ')
echo "- Total removed (restorable): $ledger"
echo "- Hide-list changes apply after a reboot."
echo "- Log: $ZF_LOG"
zf_log "action: hide=$1 removed_now=$removed ledger=$ledger"
