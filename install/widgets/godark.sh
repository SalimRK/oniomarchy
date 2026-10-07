echo "==> GoDark (radio + network kill-switch plugin)"

# Third-party Omarchy plugin, not an `omarchy pkg` target — one bar
# switch that cuts every rfkill radio plus all NetworkManager networking
# and restores exactly the previous state. Same install pattern as
# install/widgets/macarchy.sh: installed via the real `omarchy plugin`
# CLI, so shell registration/rescan is the CLI's job, not ours.

plugin_id="oniomarchy.godark"
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"

if [[ ! -d $plugin_dir ]]; then
  # --yes skips the interactive clone-warning/confirm prompts (the
  # documented scripted path — see /usr/share/omarchy/shell/README.md's
  # "Installing a third-party plugin" section); --enable turns it on
  # immediately instead of landing disabled.
  omarchy plugin add https://github.com/SalimRK/godark.git --enable --yes
else
  echo "==> $plugin_dir already present — skipping 'omarchy plugin add' (run 'omarchy plugin update $plugin_id --yes' yourself to pull updates)"
fi

# No setup step, and never root. GoDark has no `setup` command: rfkill
# works as the user through systemd's uaccess ACL on /dev/rfkill, and
# nmcli through NetworkManager's stock polkit allow_active rule. Calling
# a nonexistent `setup` is exactly what broke macarchy.sh (issue #4).
if [[ ! -x $plugin_dir/godark ]]; then
  echo "==> $plugin_dir/godark not found — plugin add may have failed" >&2
  exit 0
fi

# Manifest's own defaultSection is already "center"; moved there anyway
# so its spot next to tormarchy and macarchy is deliberate, not inherited.
# Same IPC-availability guard macarchy.sh uses — `omarchy bar move` talks
# to the running shell over IPC, so it only works with a shell already up.
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
