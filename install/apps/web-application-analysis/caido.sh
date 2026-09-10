# caido — Web Application Analysis
# pack: core
if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
  # caido-desktop (the AppImage GUI) is x86_64-only in the AUR. caido-cli
  # is the same Caido built for aarch64 (arch=(x86_64 aarch64)) — the
  # headless server you reach at its local web UI, which is Caido's real
  # interface anyway. Substitute it so this core leaf works on aarch64.
  pkg_repo caido-cli
else
  pkg_repo caido-desktop
fi
