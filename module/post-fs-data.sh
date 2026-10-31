#!/system/bin/sh
# Runs early in boot, before apps start: apply property overrides.
MODDIR=${0%/*}
# shellcheck source=lib/common.sh
. "$MODDIR/lib/common.sh"

zf_load_config
if zf_is_on "$ZUXFREE_BRANDING"; then
  zf_apply_props "$MODDIR/lists/branding.prop"
fi
if zf_is_on "$ZUXFREE_REGION_SPOOF"; then
  zf_apply_props "$MODDIR/lists/region.prop"
fi
