echo "==> Macarchy (MAC-address toggle plugin)"

# Third-party Omarchy plugin, not an `omarchy pkg` target — replaces the
# trigger.pentest.mac-randomize.* menu entries this repo built and
# removed 2026-08-27 (see notes/pentest-tools.md's Anonymity section and
# notes/Project-History.md for why). Same install pattern as
# install/widgets/tormarchy.sh: installed via the real `omarchy plugin`
# CLI, so shell registration/rescan is the CLI's job, not ours.

plugin_id="oniomarchy.macarchy"
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"

if [[ ! -d $plugin_dir ]]; then
  # --yes skips the interactive clone-warning/confirm prompts (the
  # documented scripted path — see /usr/share/omarchy/shell/README.md's
  # "Installing a third-party plugin" section); --enable turns it on
  # immediately instead of landing disabled.
  omarchy plugin add https://github.com/SalimRK/macarchy.git --enable --yes
else
  echo "==> $plugin_dir already present — skipping 'omarchy plugin add' (run 'omarchy plugin update $plugin_id --yes' yourself to pull updates)"
fi

# No setup step. macarchy 3891229 (2026-09-25) removed `setup` and
# `uninstall` along with everything they installed — the polkit rule, the
# /usr/local/bin copy, macchanger. The plugin now runs straight from its
# checkout as the user and elevates only `ip link set`, per change, so
# `omarchy plugin add` above is the whole install. Calling the removed
# `setup` made this leaf exit 1 ("unknown command: setup") and, run_step
# being fatal, stopped every install here (issue #4).
if [[ ! -x $plugin_dir/macarchy ]]; then
  echo "==> $plugin_dir/macarchy not found — plugin add may have failed" >&2
  exit 0
fi

# Manifest's own defaultSection is "right"; moved to "center" (next to
# tormarchy) per user request. Same IPC-availability guard
# tormarchy.sh uses — `omarchy bar move` talks to the running shell over
# IPC, so it only works with a shell already up.
if omarchy-shell shell ping >/dev/null 2>&1; then
  if omarchy bar move "$plugin_id" --section center >/dev/null 2>&1; then
    echo "==> Moved $plugin_id to the bar's center section."
  else
    echo "==> Could not move $plugin_id to the center section — run yourself: omarchy bar move $plugin_id --section center" >&2
  fi
else
  echo "==> No running omarchy-shell found (IPC ping failed) — once your shell is up, run:" >&2
  echo "        omarchy bar move $plugin_id --section center" >&2
fi
