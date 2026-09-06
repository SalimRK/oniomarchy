echo "==> Installing security menu action scripts"

sudo install -Dm755 "$ONIOMARCHY_INSTALL/security/tool-help.sh" /usr/local/bin/oniomarchy-tool-help
sudo install -Dm755 "$ONIOMARCHY_INSTALL/security/fern-launch.sh" /usr/local/bin/oniomarchy-fern-launch
sudo install -Dm755 "$ONIOMARCHY_INSTALL/security/gophish-launch.sh" /usr/local/bin/oniomarchy-gophish

echo "==> oniomarchy-tool-help, oniomarchy-fern-launch, oniomarchy-gophish installed to /usr/local/bin"
