#!/usr/bin/env bash
# Build the installable module zip into dist/, with a SHA-256 file and a
# matching update.json. Usage: tools/build.sh [owner/repo]
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
REPO="${1:-Thebohemiangeek/zuxfree}"
VERSION=$(grep '^version=' "$ROOT/module/module.prop" | cut -d= -f2)
CODE=$(grep '^versionCode=' "$ROOT/module/module.prop" | cut -d= -f2)
NAME="zuxfree-$VERSION.zip"
DIST="$ROOT/dist"

rm -rf "$DIST"
mkdir -p "$DIST"

# The module's system/ tree is generated on the device; never ship one.
rm -rf "$ROOT/module/system"

(
  cd "$ROOT/module"
  if command -v zip >/dev/null 2>&1; then
    zip -qr9 -X "$DIST/$NAME" . -x '.*'
  else
    # Windows: bsdtar writes zip archives with forward-slash paths.
    tar -a -cf "$DIST/$NAME" -- *
  fi
)

(cd "$DIST" && sha256sum "$NAME" > "$NAME.sha256")

cat > "$ROOT/update.json" <<EOF
{
  "version": "$VERSION",
  "versionCode": $CODE,
  "zipUrl": "https://github.com/$REPO/releases/download/$VERSION/$NAME",
  "changelog": "https://raw.githubusercontent.com/$REPO/main/CHANGELOG.md"
}
EOF

echo "Built $DIST/$NAME"
cat "$DIST/$NAME.sha256"
