# fern-wifi-cracker — Wireless Attacks
pkg_aur fern-wifi-cracker-git

# fern is architecturally built to run as root (writes into its own
# install dir, needs raw-socket access). Neither `sudo fern` nor plain
# `pkexec fern` can reach the display under Hyprland's XWayland — both
# abort identically in Qt's platform-integration init (confirmed live via
# coredumpctl, see notes/install-issues.md). oniomarchy-fern-launch (see
# install/security/fern-launch.sh) grants root a one-off `xhost`
# exception before calling pkexec; xorg-xhost isn't part of the base
# install and `xhost` isn't a fallback-shimmed binary, so it's declared
# here, with the app that actually needs it (2026-09-04).
pkg_official xorg-xhost
