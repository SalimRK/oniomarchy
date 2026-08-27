echo "==> Installing services menu action scripts"

sudo install -Dm755 "$ONIOMARCHY_INSTALL/services/service-action.sh" /usr/local/bin/service-action
sudo install -Dm755 "$ONIOMARCHY_INSTALL/services/service-confirm-action.sh" /usr/local/bin/service-confirm-action

echo "==> service-action and service-confirm-action installed to /usr/local/bin"
