#!/system/bin/sh
# Runs when the module is removed. Hidden system apps come back on their own
# (the overlay is gone); apps removed for the user are reinstalled from the
# ledger once the package manager is up.
MODDIR=${0%/*}
# shellcheck source=lib/common.sh
. "$MODDIR/lib/common.sh"

(
  zf_wait_for_boot
  sleep 10
  # shellcheck disable=SC2046  # split "<a> <b>" into $1 $2
  set -- $(zf_restore)
  zf_log "uninstall: restored $1, failed $2"
  # Keep the log for troubleshooting; drop the settings and ledger.
  rm -f "$ZF_CONFIG"
) &
