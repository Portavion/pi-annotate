#!/bin/bash
set -e

EXTENSION_ID="$1"
if [ -z "$EXTENSION_ID" ]; then
  echo "Usage: $0 <extension-id>"
  echo "Get the extension ID from chrome://extensions after loading unpacked"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_HOST_SCRIPT="$SCRIPT_DIR/host.cjs"

# Find node path (Chrome may not have node in PATH when launched from Dock)
NODE_PATH=$(which node 2>/dev/null || echo "")
if [ -z "$NODE_PATH" ]; then
  # Try common locations
  for p in /opt/homebrew/bin/node /usr/local/bin/node /usr/bin/node; do
    if [ -x "$p" ]; then
      NODE_PATH="$p"
      break
    fi
  done
fi

if [ -z "$NODE_PATH" ]; then
  echo "Error: Could not find node. Please install Node.js."
  exit 1
fi

echo "Using node at: $NODE_PATH"

if [[ "$OSTYPE" == "darwin"* ]]; then
  INSTALL_ROOT="$HOME/Library/Application Support/Pi Annotate"
  MANIFEST_DIRS=(
    "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
    "$HOME/Library/Application Support/Chromium/NativeMessagingHosts"
    "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
  )
else
  INSTALL_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/pi-annotate"
  MANIFEST_DIRS=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/google-chrome/NativeMessagingHosts"
    "${XDG_CONFIG_HOME:-$HOME/.config}/chromium/NativeMessagingHosts"
    "${XDG_CONFIG_HOME:-$HOME/.config}/BraveSoftware/Brave-Browser/NativeMessagingHosts"
  )
fi

mkdir -p "$INSTALL_ROOT"
HOST_SCRIPT="$INSTALL_ROOT/host.cjs"
HOST_PATH="$INSTALL_ROOT/host-wrapper.sh"
cp "$SOURCE_HOST_SCRIPT" "$HOST_SCRIPT"
chmod +x "$HOST_SCRIPT"

# Create wrapper script with absolute node path in a stable install location
cat > "$HOST_PATH" << EOF
#!/bin/bash
exec "$NODE_PATH" "$HOST_SCRIPT" "\$@"
EOF
chmod +x "$HOST_PATH"

for MANIFEST_DIR in "${MANIFEST_DIRS[@]}"; do
  mkdir -p "$MANIFEST_DIR"
  cat > "$MANIFEST_DIR/com.pi.annotate.json" << EOF
{
  "name": "com.pi.annotate",
  "description": "Pi Annotate native messaging host",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$EXTENSION_ID/"
  ]
}
EOF
  echo "Installed native host manifest to: $MANIFEST_DIR/com.pi.annotate.json"
done

echo "Installed native host files to: $INSTALL_ROOT"
echo "Restart your browser for changes to take effect."
