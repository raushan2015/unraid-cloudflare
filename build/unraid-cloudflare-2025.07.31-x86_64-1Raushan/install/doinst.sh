#!/bin/bash
# Add boot hook if not already there
if ! grep -q "rc.cloudflare boot" /boot/config/go; then
  echo "/usr/local/emhttp/plugins/unraid-cloudflare/scripts/rc.cloudflare boot &" >> /boot/config/go
fi
