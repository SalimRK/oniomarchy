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
# password) — all real system changes, but deliberately NOT under sudo,
# unlike tormarchy.sh's otherwise identical line. macarchy's setup
# elevates itself and *refuses* to start already-root ("don't run this
# with sudo yourself -- run 'macarchy setup' ... and it elevates safely
# on its own", its elevate_frozen()). The refusal is the point: $SELF at
# setup time is still this user-writable plugin checkout, so
# elevate_frozen() reads its own bytes while unprivileged and pipes them
# to a fixed root bootstrap that re-executes them from a root-owned
# copy — root never reads from a path a same-UID process could rewrite
# mid-run. `sudo macarchy setup` would be exactly the hole that guards
# against, so it exits non-zero, and run_step is fatal: that is what
# aborted the whole install before this summary.
#
# The catch: setup/uninstall have no pkexec path (by design — the polkit
# rule must not reach them), so elevate_frozen() insists on a terminal on
# stdin, and ui_exec runs quiet-mode steps with stdin on /dev/null. Hand
# it the controlling terminal explicitly. Quiet mode only happens when
# ui_can_draw saw a tty on stdout, so /dev/tty is there; verbose mode
# inherits our stdin, tty or not. With neither, skip with instructions
# rather than abort — losing macchanger is not worth losing the run.
# The sudo inside elevate_frozen won't prompt: install.sh's up-front
# `sudo -v` plus its keepalive means the credentials are already cached.
# Every step inside `setup` is itself check-then-install, so rerunning
# this leaf is safe.
echo "==> Running macarchy setup (installs macchanger, polkit rule — elevates itself, so no sudo here)"
if [[ -t 0 ]]; then
  "$plugin_dir/macarchy" setup
# 2> first: redirections apply left to right, so stderr is already
# silenced when the /dev/tty open fails and prints.
elif : 2>/dev/null < /dev/tty; then
  "$plugin_dir/macarchy" setup < /dev/tty
else
  echo "==> No terminal on stdin and no /dev/tty — macarchy setup needs one (it has no pkexec path). Run yourself: $plugin_dir/macarchy setup" >&2
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
