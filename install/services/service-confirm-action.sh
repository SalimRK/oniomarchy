#!/usr/bin/env bash
#
# Root-owned start/stop/restart target for the two services menu entries
# that need CLAUDE.md's confirm-before-enable UX (sshd, xrdp — enabling
# either opens remote-access attack surface on a machine that's likely
# carrying client creds/loot on untrusted networks). Installed to
# /usr/local/bin/service-confirm-action by
# install/services/install-scripts.sh, invoked via
# `omarchy-launch-tui bash -c 'sudo service-confirm-action "<label>" <action> <unit...>; exec bash'`
# — sudo, not pkexec, since gum confirm needs a real terminal (see
# CLAUDE.md's privilege-escalation rule: sudo for terminal-visible
# commands).
#
# Only start/restart gate behind gum confirm (both can newly expose the
# service); stop never confirms, matching the non-confirm services'
# service-action.sh behavior — reuses the same `omarchy-update-confirm`-
# style `gum style` + `gum confirm` pattern Omarchy itself uses before its
# own risky action (see /usr/share/omarchy/bin/omarchy-update-confirm).

set -euo pipefail

label="${1:?usage: service-confirm-action <label> <start|stop|restart> <unit> [unit...]}"
shift
action="${1:?usage: service-confirm-action <label> <start|stop|restart> <unit> [unit...]}"
shift
[[ $# -ge 1 ]] || { echo "usage: service-confirm-action <label> <start|stop|restart> <unit> [unit...]" >&2; exit 1; }

case "$action" in
  start|stop|restart) ;;
  *) echo "service-confirm-action: unknown action '$action'" >&2; exit 1 ;;
esac

if [[ $action == start || $action == restart ]]; then
  gum style --border normal --padding "1 2" \
    "${action^} $label?" \
    "" \
    "This opens remote-access attack surface on this machine." \
    "Make sure you actually intend to accept incoming connections."
  echo
  if ! gum confirm "${action^} $label now?"; then
    echo "Cancelled — $label left as-is."
    exit 0
  fi
fi

systemctl "$action" "$@"
echo "==> $label: $action complete."
