#!/usr/bin/env bash
#
# fern (fern-wifi-cracker-git) is architecturally built to run fully as
# root — it writes .font_settings.dat and a cookie-hijacker SQLite DB
# straight into its own /usr/share/fern-wifi-cracker install directory,
# and even self-updates that directory (chmod 777 on every file) on
# every launch. This matches Kali's own packaging: their
# /usr/bin/fern-wifi-cracker is the identical `cd
# /usr/share/fern-wifi-cracker/; exec python3 execute.py`, and their own
# docs just say `sudo fern-wifi-cracker` — no menu launcher at all.
#
# Neither `sudo fern` nor plain `pkexec fern` can reach the display under
# Hyprland's XWayland — both were tested live (2026-09-03/04) and both
# abort identically: Qt's QGuiApplicationPrivate::createPlatformIntegration
# calls qFatal() and the process SIGABRTs (confirmed from the real
# coredump via coredumpctl, not guessed — pkexec's version fails silent,
# since it never surfaces the child's stderr anywhere). Two things are
# missing, both confirmed by testing, not assumed:
#   1. `pkexec env` shows it strips DISPLAY/XAUTHORITY entirely — Qt has
#      no display to even attempt connecting to. Passed through
#      explicitly via `env DISPLAY=...` (pkexec has no `VAR=val cmd`
#      syntax of its own, unlike sudo, so `env` is the vehicle).
#   2. Even with DISPLAY present, root still needs the X server's
#      permission to connect — `xhost +si:localuser:root` grants that
#      outright, independent of cookie/env forwarding, so it has to run
#      as the *unprivileged* user (this script itself, before pkexec),
#      not inside the root context that needs it. Revoked again once
#      fern exits so the grant doesn't outlive this run.
# Both were needed together — DISPLAY alone still gets refused by the X
# server's access control, and the xhost grant alone is never reached
# because Qt never had a display to try in the first place.
#
# Installed to /usr/local/bin/oniomarchy-fern-launch by
# install-scripts.sh. Run directly from the menu with no terminal
# wrapper (unlike tool-help.sh's CLI branch) — pkexec's own themed
# polkit dialog is the password prompt, so no TTY is needed:
#   oniomarchy-fern-launch

set -uo pipefail

if ! command -v xhost >/dev/null 2>&1; then
  notify-send "fern" "'xhost' not found — install xorg-xhost first (pacman -S xorg-xhost)." 2>/dev/null
  echo "oniomarchy-fern-launch: 'xhost' not found — install xorg-xhost first (pacman -S xorg-xhost)." >&2
  exit 1
fi

xhost +si:localuser:root

pkexec env DISPLAY="$DISPLAY" fern
rc=$?

xhost -si:localuser:root >/dev/null

exit $rc
