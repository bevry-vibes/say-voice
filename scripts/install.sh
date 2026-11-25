#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BIN_DIR=${BIN_DIR:-"$HOME/.local/bin"}
SHARE_DIR=${SHARE_DIR:-"$HOME/.local/share/say-voice"}

"$ROOT/scripts/build.sh"
mkdir -p "$BIN_DIR" "$SHARE_DIR"
cp "$ROOT/.build/say-voice.swift" "$SHARE_DIR/say-voice.swift"

cat > "$BIN_DIR/say-voice" <<EOF
#!/bin/sh
set -eu
if ! command -v swift >/dev/null 2>&1; then
	echo "say-voice: the Swift interpreter is required. Install Xcode Command Line Tools." >&2
	exit 1
fi
exec swift "$SHARE_DIR/say-voice.swift" "\$@"
EOF

chmod +x "$BIN_DIR/say-voice"

echo "Installed: $BIN_DIR/say-voice"
echo "Script: $SHARE_DIR/say-voice.swift"
