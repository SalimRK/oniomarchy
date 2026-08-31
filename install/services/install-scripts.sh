echo "==> Installing services menu action scripts"

sudo install -Dm755 "$ONIOMARCHY_INSTALL/services/service-action.sh" /usr/local/bin/service-action
sudo install -Dm755 "$ONIOMARCHY_INSTALL/services/service-confirm-action.sh" /usr/local/bin/service-confirm-action

echo "==> service-action and service-confirm-action installed to /usr/local/bin"

# beef.service is NOT installed here any more. It moved to
# install/apps/exploitation/ (with beef.sh, the script that installs
# beef-xss) — shipped config belongs with its application. This category
# still owns the Start/Stop/Restart menu for it via services.tsv.
