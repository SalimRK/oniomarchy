#!/usr/bin/env bash
#
# Launches recon-ng from its own user-owned venv. Installed to
# /usr/local/bin/recon-ng by
# install/apps/information-gathering/recon-ng.sh on aarch64, where the AUR
# recon-ng cannot build (its flasgger dep is pip-only, absent from the
# AUR) — so the tool is installed git+venv instead, like
# ai-tools/hexstrike-ai.sh. recon-ng ships no console-script entry point;
# it is run as `recon-ng` from its checkout, so the venv python runs that
# script directly.
#
# $HOME resolves at run time to whoever launches this — not baked in.
exec "$HOME/.local/share/oniomarchy/recon-ng/env/bin/python" \
  "$HOME/.local/share/oniomarchy/recon-ng/recon-ng" "$@"
