#!/bin/bash
# Build script for Unraid Cloudflare plugin
# Author: Raushan

PLUGIN="unraid-cloudflare"
VERSION="2025.07.31"
ARCH="x86_64"
PKG="$PLUGIN-$VERSION-$ARCH-1Raushan"

# Cleanup
rm -rf build
mkdir -p build/$PKG

# Directory layout
mkdir -p build/$PKG/usr/local/emhttp/plugins/$PLUGIN/scripts
mkdir -p build/$PKG/install

#########################################
# rc.cloudflare (service script)
#########################################
cat << 'EOF' > build/$PKG/usr/local/emhttp/plugins/$PLUGIN/scripts/rc.cloudflare
#!/bin/bash
# rc.cloudflare - manage Cloudflare Tunnel

CLOUDFLARED_BIN="/usr/local/bin/cloudflared"
TOKEN_FILE="/boot/config/plugins/unraid-cloudflare/token.txt"
CONFIG_FILE="/boot/config/plugins/unraid-cloudflare/settings.conf"
LOG_FILE="/var/log/cloudflare.log"

# Read settings
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

case "$1" in
  start)
    if [[ -f "$TOKEN_FILE" ]]; then
      nohup $CLOUDFLARED_BIN tunnel --no-autoupdate run --token $(cat $TOKEN_FILE) >> $LOG_FILE 2>&1 &
      echo $! > /var/run/cloudflare.pid
      echo "Cloudflare tunnel started"
    else
      echo "No token file found"
    fi
    ;;
  stop)
    if [[ -f /var/run/cloudflare.pid ]]; then
      kill $(cat /var/run/cloudflare.pid)
      rm -f /var/run/cloudflare.pid
      echo "Stopped"
    else
      echo "Not running"
    fi
    ;;
  restart)
    $0 stop
    sleep 2
    $0 start
    ;;
  status)
    [[ -f /var/run/cloudflare.pid ]] && echo "Running" || echo "Stopped"
    ;;
  boot)
    if [[ "$AUTOSTART" == "1" ]]; then
      $0 start
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|boot}"
    ;;
esac
EOF
chmod +x build/$PKG/usr/local/emhttp/plugins/$PLUGIN/scripts/rc.cloudflare

#########################################
# install.sh
#########################################
cat << 'EOF' > build/$PKG/usr/local/emhttp/plugins/$PLUGIN/scripts/install.sh
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
EOF
chmod +x build/$PKG/usr/local/emhttp/plugins/$PLUGIN/scripts/install.sh

#########################################
# remove.sh
#########################################
cat << 'EOF' > build/$PKG/usr/local/emhttp/plugins/$PLUGIN/scripts/remove.sh
#!/bin/bash
echo "Removing Cloudflare Unraid Plugin"
# Keep cloudflared binary in case user uses it outside plugin
EOF
chmod +x build/$PKG/usr/local/emhttp/plugins/$PLUGIN/scripts/remove.sh

#########################################
# WebUI page
#########################################
cat << 'EOF' > build/$PKG/usr/local/emhttp/plugins/$PLUGIN/cloudflare.page
<?php
$docroot = $docroot ?? $_SERVER['DOCUMENT_ROOT'] ?: '/usr/local/emhttp';
require_once "$docroot/webGui/include/Helpers.php";

$tokenFile = "/boot/config/plugins/unraid-cloudflare/token.txt";
$configFile = "/boot/config/plugins/unraid-cloudflare/settings.conf";

if (isset($_POST['token']) && $_POST['token']) {
    file_put_contents($tokenFile, trim($_POST['token']));
    shell_exec("/usr/local/emhttp/plugins/unraid-cloudflare/scripts/rc.cloudflare restart");
}

if (isset($_POST['autostart'])) {
    $autostart = ($_POST['autostart'] == "1") ? "1" : "0";
    file_put_contents($configFile, "AUTOSTART=$autostart\n");
}

$settings = [];
if (file_exists($configFile)) {
    $settings = parse_ini_file($configFile);
}
$autostartValue = $settings['AUTOSTART'] ?? "0";
?>

<div>
  <h2>Cloudflare Zero Trust</h2>
  <form method="POST">
    <label>Enter Cloudflare Tunnel Token:</label><br>
    <input type="password" name="token" value="">
    <button type="submit">Save & Restart</button>
  </form>

  <form method="POST" style="margin-top:20px;">
    <label>
      <input type="hidden" name="autostart" value="0">
      <input type="checkbox" name="autostart" value="1" <?=($autostartValue=="1"?"checked":"")?>>
      Auto-start tunnel on boot
    </label>
    <button type="submit">Save</button>
  </form>

  <h3>Status</h3>
  <pre><?=shell_exec("/usr/local/emhttp/plugins/unraid-cloudflare/scripts/rc.cloudflare status");?></pre>

  <h3>Logs</h3>
  <pre><?=shell_exec("tail -n 20 /var/log/cloudflare.log");?></pre>
</div>
EOF

#########################################
# doinst.sh (post install hook)
#########################################
cat << 'EOF' > build/$PKG/install/doinst.sh
#!/bin/bash
# Add boot hook if not already there
if ! grep -q "rc.cloudflare boot" /boot/config/go; then
  echo "/usr/local/emhttp/plugins/unraid-cloudflare/scripts/rc.cloudflare boot &" >> /boot/config/go
fi
EOF

#########################################
# Package
#########################################
cd build/$PKG
makepkg -l y -c n ../../$PKG.txz
cd ../../

echo "✅ Built package: $PKG.txz"
