#!/usr/bin/env bash
#
# Quick HTTP file server from an arbitrary directory — the launch target
# for Trigger > Pentest > HTTP File Server > Custom Directory, and for
# `oniomarchy net http-server`. Installed to
# /usr/local/bin/oniomarchy-http-server by
# install/trigger/install-scripts.sh. Extracted 2026-09-09 from an inline
# action string in install/trigger/menu.sh so the CLI could call the same
# logic without duplicating it — see notes/oniomarchy-cli.md.
#
# Usage:
#   oniomarchy-http-server <dir> <port>
#
# Uses python3 explicitly (not python) since this machine's mise shim can
# sit ahead of system python on PATH — see CLAUDE.md's mise note.

set -euo pipefail

dir="${1:?usage: oniomarchy-http-server <dir> <port>}"
port="${2:?usage: oniomarchy-http-server <dir> <port>}"

if [[ ! -d $dir ]]; then
  echo "oniomarchy-http-server: no such directory: $dir" >&2
  exit 1
fi
if [[ ! $port =~ ^[0-9]+$ ]]; then
  echo "oniomarchy-http-server: not a port number: $port" >&2
  exit 1
fi

cd "$dir"
exec python3 -m http.server "$port"
