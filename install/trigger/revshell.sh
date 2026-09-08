#!/usr/bin/env bash
#
# Reverse-shell listener — the launch target for Trigger > Pentest >
# Reverse Shell Listener, and for `oniomarchy net revshell`. Installed to
# /usr/local/bin/oniomarchy-revshell by
# install/trigger/install-scripts.sh. Extracted 2026-09-09 from an inline
# action string in install/trigger/menu.sh so the CLI could call the same
# logic without duplicating it — see notes/oniomarchy-cli.md.
#
# Usage:
#   oniomarchy-revshell <port>
#
# Uses ncat (from nmap) rather than the classic nc binary — see
# install/trigger/menu.sh for why. No root required to listen on a normal
# (>1024) port.

set -euo pipefail

port="${1:?usage: oniomarchy-revshell <port>}"

if [[ ! $port =~ ^[0-9]+$ ]]; then
  echo "oniomarchy-revshell: not a port number: $port" >&2
  exit 1
fi

exec ncat -lvnp "$port"
