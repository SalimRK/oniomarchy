echo "==> Installing security menu action scripts"

sudo install -Dm755 "$ONIOMARCHY_INSTALL/security/tool-help.sh" /usr/local/bin/oniomarchy-tool-help
sudo install -Dm755 "$ONIOMARCHY_INSTALL/security/fern-launch.sh" /usr/local/bin/oniomarchy-fern-launch

echo "==> oniomarchy-tool-help, oniomarchy-fern-launch installed to /usr/local/bin"
