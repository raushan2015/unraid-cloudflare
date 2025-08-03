#!/bin/bash
echo "🔹 Installing Cloudflare Unraid Plugin"

CONFIG_FILE="/boot/config/plugins/unraid-cloudflare/settings.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "AUTOSTART=0" > "$CONFIG_FILE"
fi

BIN="/usr/local/bin/cloudflared"
if [[ ! -f "$BIN" ]]; then
  echo "⬇️ Downloading latest cloudflared..."
  URL=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest \
    | grep browser_download_url \
    | grep linux-amd64 \
    | cut -d '"' -f 4)
  wget -O "$BIN" "$URL"
  chmod +x "$BIN"
  echo "✅ cloudflared installed at $BIN"
else
  echo "✅ cloudflared already installed"
fi
