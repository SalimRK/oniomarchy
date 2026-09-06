#!/usr/bin/env bash
#
# oniomarchy-gophish — launcher for the gophish phishing framework.
#
# gophish resolves VERSION, config.json, db/, static/ and templates/
# relative to the current working directory, and writes gophish.db plus a
# generated gophish_admin.crt/.key beside them. The Arch `gophish` package
# installs those assets to /usr/share/gophish (root-owned, not
# user-writable) and its systemd unit runs there as root — so a normal
# user has nowhere to run it from: bare `gophish` at $HOME dies instantly
# on `open ./VERSION: no such file or directory`, and
# `cd /usr/share/gophish && gophish` can't create its db/cert either.
# (Confirmed live 2026-09-06 — see notes/install-issues.md.)
#
# This seeds a per-user data dir: the read-only package assets are
# symlinked (so they follow package updates), and config.json is copied
# once (so the user's own edits survive reruns). The shipped config binds
# the phishing server to 0.0.0.0:80, which a non-root user cannot bind
# (gophish fatals `bind: permission denied` right after the DB migration),
# so the seeded copy moves it to 0.0.0.0:8080; the admin UI keeps its
# default 127.0.0.1:3333. Edit
# ~/.local/share/oniomarchy/gophish/config.json to change either.
#
# Installed to /usr/local/bin/oniomarchy-gophish by install-scripts.sh.
# Launched from the Security menu inside a terminal (gophish runs in the
# foreground and prints the generated admin password), so the menu action
# wraps it in omarchy-launch-tui — see oniomarchy_custom_action["gophish"]
# in verify-binaries.sh.

set -uo pipefail

pkgdir=/usr/share/gophish
datadir="${XDG_DATA_HOME:-$HOME/.local/share}/oniomarchy/gophish"

if [[ ! -d $pkgdir ]]; then
  echo "oniomarchy-gophish: $pkgdir not found — is the gophish package installed?" >&2
  exit 1
fi

mkdir -p "$datadir"

# Read-only package assets: symlink rather than copy, so they track
# package updates. -sfn keeps reruns idempotent and repoints a stale link
# if the package layout ever moves.
for asset in VERSION static templates db; do
  ln -sfn "$pkgdir/$asset" "$datadir/$asset"
done

# config.json: seed once so the user's edits (phish port, contact address,
# TLS) survive reruns. Move the phishing server onto an unprivileged port
# so it starts without root; jq preserves the rest of the packaged config
# verbatim, falling back to a straight copy if jq isn't present.
if [[ ! -f $datadir/config.json ]]; then
  if command -v jq >/dev/null 2>&1; then
    jq '.phish_server.listen_url = "0.0.0.0:8080"' "$pkgdir/config.json" > "$datadir/config.json"
  else
    cp "$pkgdir/config.json" "$datadir/config.json"
  fi
fi

echo "gophish data dir: $datadir"
echo "admin UI: https://127.0.0.1:3333  (self-signed cert; the initial admin login/password is printed below on first run)"
echo

cd "$datadir" || exit 1
exec gophish "$@"
