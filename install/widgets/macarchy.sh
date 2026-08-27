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

if [[ ! -x $plugin_dir/macarchy ]]; then
  echo "==> $plugin_dir/macarchy not found — plugin add may have failed, skipping setup" >&2
  exit 0
fi

# macarchy's own `setup` installs macchanger, the macarchy binary itself
# to /usr/local/bin, and a polkit rule (so toggling doesn't prompt for a
# password) — all real system changes, hence sudo. Every step inside
# `setup` is itself check-then-install, so rerunning this leaf is safe.
echo "==> Running macarchy setup (installs macchanger, polkit rule — needs sudo)"
sudo "$plugin_dir/macarchy" setup

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
