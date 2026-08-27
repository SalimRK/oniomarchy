echo "==> Installing services menu action scripts"

sudo install -Dm755 "$ONIOMARCHY_INSTALL/services/service-action.sh" /usr/local/bin/service-action
sudo install -Dm755 "$ONIOMARCHY_INSTALL/services/service-confirm-action.sh" /usr/local/bin/service-confirm-action

echo "==> service-action and service-confirm-action installed to /usr/local/bin"

# beef-xss ships no systemd unit of its own (its docs say to run `sudo beef`
# directly) — install our own, then reload so systemctl picks it up. Not
# enabled/started here, same as every other row in services.tsv: presence
# only, the menu's Start/Stop/Restart control actual state.
if pacman -Qq beef-xss >/dev/null 2>&1; then
  sudo install -Dm644 "$ONIOMARCHY_INSTALL/services/beef.service" /etc/systemd/system/beef.service
  sudo systemctl daemon-reload
  echo "==> beef.service installed to /etc/systemd/system"
fi
