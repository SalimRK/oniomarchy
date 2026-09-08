#!/usr/bin/env bash
#
# Serve winPEAS from its real installed peass-ng path — the launch target
# for Trigger > Pentest > HTTP File Server > Serve winPEAS, and for
# `oniomarchy net winpeas`. Installed to
# /usr/local/bin/oniomarchy-serve-winpeas by
# install/trigger/install-scripts.sh. Extracted 2026-09-09 from an inline
# action string in install/trigger/menu.sh so the CLI could call the same
# logic without duplicating it — see notes/oniomarchy-cli.md.
#
# Usage:
#   oniomarchy-serve-winpeas [port]      # default 8000, python's own default

set -euo pipefail

dir=/usr/share/peass-ng/windows
port="${1:-8000}"

if [[ ! -d $dir ]]; then
  echo "oniomarchy-serve-winpeas: $dir not found — is peass-ng installed?" >&2
  exit 1
fi
if [[ ! $port =~ ^[0-9]+$ ]]; then
  echo "oniomarchy-serve-winpeas: not a port number: $port" >&2
  exit 1
fi

cd "$dir"
exec python3 -m http.server "$port"
