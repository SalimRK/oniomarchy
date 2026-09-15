# [oniomarchy] publishes x86_64 signed binaries; aarch64 builds
# non-official tools from the AUR instead (ONIOMARCHY_AUR_FALLBACK, set in
# install.sh). Anything else has neither path and stops here, before
# /etc/pacman.conf is touched — the fail-fast issue #1 asked for. Runs
# right after require-omarchy.sh, so nothing has been changed yet.
#
# On x86_64 this is a silent no-op.
case "$(uname -m)" in
  x86_64) ;;
  aarch64)
    echo "==> Architecture aarch64: [oniomarchy] is x86_64-only, so"
    echo "    non-official tools will be built from the AUR (this is slower)."
    ;;
  *)
    echo "error: unsupported architecture '$(uname -m)' — oniomarchy installs on x86_64 (signed binaries) and aarch64 (AUR builds)." >&2
    exit 1
    ;;
esac
