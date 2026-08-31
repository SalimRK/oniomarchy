#!/usr/bin/env bash
#
# Launches HexStrike AI's MCP server from its own user-owned venv.
# Installed to /usr/local/bin/hexstrike-server by
# install/apps/ai-tools/hexstrike-ai.sh, which clones the repo and builds the
# venv at $HOME/.local/share/oniomarchy/hexstrike-ai.
#
# $HOME resolves at run time to whoever launches this (via the Security
# menu, as any other user-owned tool here) — not baked in at install time.
exec "$HOME/.local/share/oniomarchy/hexstrike-ai/hexstrike-env/bin/python3" \
  "$HOME/.local/share/oniomarchy/hexstrike-ai/hexstrike_server.py" "$@"
