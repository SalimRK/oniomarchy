#!/usr/bin/env bash
#
# Root-owned start/stop/restart target for services menu entries that don't
# need the confirm-before-enable gate (samba, vsftpd, postgresql — see
# services-confirm-action.sh for sshd/xrdp). Installed to
# /usr/local/bin/service-action by install/services/install-scripts.sh,
# invoked via `pkexec service-action <start|stop|restart> <unit...>` since
# it's triggered from a background menu click, not a visible terminal (see
# CLAUDE.md's privilege-escalation rule).

set -euo pipefail

action="${1:?usage: service-action <start|stop|restart> <unit> [unit...]}"
shift
[[ $# -ge 1 ]] || { echo "usage: service-action <start|stop|restart> <unit> [unit...]" >&2; exit 1; }

case "$action" in
  start|stop|restart) ;;
  *) echo "service-action: unknown action '$action'" >&2; exit 1 ;;
esac

systemctl "$action" "$@"
