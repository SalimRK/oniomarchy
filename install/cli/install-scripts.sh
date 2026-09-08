echo "==> Installing oniomarchy CLI"

sudo install -Dm755 "$ONIOMARCHY_INSTALL/cli/oniomarchy" /usr/local/bin/oniomarchy
for g in tool service net repo branding doctor; do
  sudo install -Dm755 "$ONIOMARCHY_INSTALL/cli/lib/oniomarchy-$g" "/usr/local/lib/oniomarchy/oniomarchy-$g"
done
sudo install -Dm644 "$ONIOMARCHY_INSTALL/cli/lib/json.sh" /usr/local/lib/oniomarchy/json.sh

# Mirrored so repo/branding/doctor keep working after this checkout is
# gone — same pattern as the oniomarchy-tool-help/oniomarchy-proxy-trust
# install-time copies below, not a second hand-maintained copy of
# strap.sh's trust anchor (see its own header comment): this is a plain
# snapshot refreshed on every install.sh run, same category as any other
# generated state under ~/.local/state/oniomarchy/. Laid out to mirror
# $ONIOMARCHY_PATH/$ONIOMARCHY_INSTALL exactly, so strap.sh,
# verify-binaries.sh, verify-units.sh and branding.sh run against it
# completely unmodified once oniomarchy-repo/-branding/-doctor point
# ONIOMARCHY_PATH/ONIOMARCHY_INSTALL at /usr/local/share/oniomarchy.
echo "==> Mirroring CLI support files (checkout-independent repo/branding/doctor)"
sudo install -Dm755 "$ONIOMARCHY_INSTALL/repo/strap.sh" \
  /usr/local/share/oniomarchy/install/repo/strap.sh
sudo install -Dm755 "$ONIOMARCHY_INSTALL/security/verify-binaries.sh" \
  /usr/local/share/oniomarchy/install/security/verify-binaries.sh
sudo install -Dm644 "$ONIOMARCHY_INSTALL/security/categories.tsv" \
  /usr/local/share/oniomarchy/install/security/categories.tsv
sudo install -Dm755 "$ONIOMARCHY_INSTALL/services/verify-units.sh" \
  /usr/local/share/oniomarchy/install/services/verify-units.sh
sudo install -Dm644 "$ONIOMARCHY_INSTALL/services/services.tsv" \
  /usr/local/share/oniomarchy/install/services/services.tsv
sudo install -Dm755 "$ONIOMARCHY_INSTALL/themes/branding.sh" \
  /usr/local/share/oniomarchy/install/themes/branding.sh
sudo install -Dm644 "$ONIOMARCHY_PATH/themes/branding/oniomarchy-about.txt" \
  /usr/local/share/oniomarchy/themes/branding/oniomarchy-about.txt
sudo install -Dm644 "$ONIOMARCHY_PATH/themes/branding/oniomarchy-screensaver.txt" \
  /usr/local/share/oniomarchy/themes/branding/oniomarchy-screensaver.txt

echo "==> oniomarchy CLI installed to /usr/local/bin"
