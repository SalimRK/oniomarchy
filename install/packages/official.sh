mapfile -t oniomarchy_official_packages < <(grep -v '^#' "$ONIOMARCHY_INSTALL/packages/official.packages" | grep -v '^$')

echo "==> Installing official packages..."
omarchy pkg add "${oniomarchy_official_packages[@]}"
