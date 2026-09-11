#!/usr/bin/env bash
#
# Launches theHarvester from its own user-owned venv. Installed to
# /usr/local/bin/theHarvester by
# install/apps/information-gathering/theharvester.sh on aarch64, where the
# AUR theharvester-git cannot build (its python-aiomultiprocess dep is a
# broken/stale AUR package) — so the tool is installed git+venv instead,
# exactly like ai-tools/hexstrike-ai.sh.
#
# $HOME resolves at run time to whoever launches this (via the terminal or
# the Security menu) — not baked in at install time.
exec "$HOME/.local/share/oniomarchy/theharvester/env/bin/theHarvester" "$@"
