source "$ONIOMARCHY_INSTALL/packages/lib-clean-build-path.sh"

mapfile -t oniomarchy_aur_packages < <(grep -v '^#' "$ONIOMARCHY_INSTALL/packages/aur.packages" | grep -v '^$')

echo "==> Installing AUR packages..."
omarchy pkg aur add "${oniomarchy_aur_packages[@]}"
