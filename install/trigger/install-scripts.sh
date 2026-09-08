echo "==> Installing trigger menu action scripts"

sudo install -Dm755 "$ONIOMARCHY_INSTALL/trigger/proxy-trust.sh" /usr/local/bin/oniomarchy-proxy-trust
sudo install -Dm755 "$ONIOMARCHY_INSTALL/trigger/revshell.sh" /usr/local/bin/oniomarchy-revshell
sudo install -Dm755 "$ONIOMARCHY_INSTALL/trigger/http-server.sh" /usr/local/bin/oniomarchy-http-server
sudo install -Dm755 "$ONIOMARCHY_INSTALL/trigger/serve-linpeas.sh" /usr/local/bin/oniomarchy-serve-linpeas
sudo install -Dm755 "$ONIOMARCHY_INSTALL/trigger/serve-winpeas.sh" /usr/local/bin/oniomarchy-serve-winpeas

echo "==> trigger menu action scripts installed to /usr/local/bin"
