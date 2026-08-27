# No hook leaves yet. The originally-suspected need — re-applying
# security/webapps/trigger menu jsonc after `omarchy update`/`omarchy
# refresh shell` wipes ~/.config/omarchy/extensions/omarchy-menu.jsonc —
# was checked against the real Omarchy source (2026-08-26) and does NOT
# hold:
#   - omarchy-refresh-shell only touches shell.json (omarchy-refresh-config
#     omarchy/shell.json + omarchy-bar defaults + restart) — never the
#     extensions file.
#   - omarchy update's omarchy-migrate step: none of the shipped migrations
#     touch extensions/omarchy-menu.jsonc (checked every migration that
#     matched grep -rl "extensions" under /usr/share/omarchy/{bin,migrations}
#     — all hits were Chromium *browser* extensions, an unrelated same-word
#     collision, not this file).
# The only things that DO wipe it are both explicit, user-confirmed
# destructive actions, not silent ones: `omarchy refresh config
# omarchy/extensions/omarchy-menu.jsonc` (naming that exact file), or
# `omarchy reinstall` (gated behind a "lose config changes?" gum confirm).
# Neither needs a hook to guard against — the user already knows they're
# resetting configs when they run either one; rerunning this repo's own
# install.sh afterward is the natural recovery, same as today.
#
# So: no real need identified yet. If a future Omarchy version adds a
# migration that does touch the extensions file, or another real
# system-event need for a hook turns up, register it via `omarchy hook
# install <event> <script>` (never edit packaged files directly) and add
# `run_step "$ONIOMARCHY_INSTALL/hooks/<name>.sh"` lines here.
