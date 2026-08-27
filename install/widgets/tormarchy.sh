echo "==> Tormarchy (Tor toggle plugin)"

# Third-party Omarchy plugin, not an `omarchy pkg` target — replaces the
# archtorify-git-based bar widget this repo built and removed 2026-08-27
# (see notes/pentest-tools.md's Anonymity section and
# notes/Project-History.md for why). Installed via the real `omarchy
# plugin` CLI (not a hand-copied manifest.json + QML like the old
# oniomarchy.toggles widget was), so shell registration/rescan is the
# CLI's job, not ours.

plugin_id="tripleu.tor"
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"

if [[ ! -d $plugin_dir ]]; then
  # --yes skips the interactive clone-warning/confirm prompts (this is
  # the documented scripted path — see /usr/share/omarchy/shell/README.md's
  # "Installing a third-party plugin" section); --enable turns it on
  # immediately instead of landing disabled.
  omarchy plugin add https://github.com/TripleU613/tormarchy.git --enable --yes
else
  echo "==> $plugin_dir already present — skipping 'omarchy plugin add' (run 'omarchy plugin update $plugin_id --yes' yourself to pull updates)"
fi

if [[ ! -x $plugin_dir/tormarchy ]]; then
  echo "==> $plugin_dir/tormarchy not found — plugin add may have failed, skipping setup" >&2
  exit 0
fi

# tormarchy's own `setup` installs tor, a torrc.d config snippet, a polkit
# rule (so connecting doesn't prompt for a password), and adds the user to
# the `tor` group — all real system changes, hence sudo. Every step inside
# `setup` is itself check-then-install (confirmed by reading the real
# script), so rerunning this leaf is safe.
echo "==> Running tormarchy setup (installs tor, torrc config, polkit rule — needs sudo)"
sudo "$plugin_dir/tormarchy" setup

# Manifest's own defaultSection is "right"; moved to "center" per user
# request. `omarchy bar move` talks to the running shell over IPC
# (omarchy-shell shell moveBarWidget), so it only works with a shell
# already up — same guard the old archtorify.sh used before calling
# rescanPlugins.
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
