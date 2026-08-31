#!/usr/bin/env bash
#
# Oniomarchy installer — an overlay on top of a stock Omarchy system.
# See notes/ROADMAP.md (scope), notes/pentest-tools.md (tool/menu/
# services plan), notes/per-app-scripts.md (the one-app-one-script layout
# under install/apps/), notes/install-layout.md (this script's own layout,
# adapted from Omarchy's real install/ structure —
# notes/omarchy-script-structure.md), and notes/install-ui.md (the output
# design: quiet by default, always logged).
#
# Does everything the Omarchy way: `omarchy pkg add`, `omarchy hook install`,
# ~/.config/omarchy/extensions/omarchy-menu.jsonc — never touches
# /usr/share/omarchy/ (package-owned, wiped on `omarchy update`).

set -euo pipefail

ONIOMARCHY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ONIOMARCHY_PATH
export ONIOMARCHY_INSTALL="$ONIOMARCHY_PATH/install"

# --- options --------------------------------------------------------------

ONIOMARCHY_VERBOSE=0
ONIOMARCHY_LOG=""
_oniomarchy_no_log=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

  -v, --verbose     show every package manager line as it happens
                    (the default shows one progress line instead)
      --log PATH    write the log somewhere other than
                    ~/.local/state/oniomarchy/install-<timestamp>.log
      --no-log      don't keep a log file
  -h, --help        this message

Both modes write the same output to the log. Quiet mode falls back to
verbose automatically when there is no terminal to draw on — a piped or
redirected run, so that captured logs stay readable.
USAGE
}

while (( $# )); do
  case "$1" in
    -v|--verbose) ONIOMARCHY_VERBOSE=1 ;;
    --log)        [[ $# -ge 2 ]] || { echo "--log needs a path" >&2; exit 2; }
                  ONIOMARCHY_LOG="$2"; shift ;;
    --log=*)      ONIOMARCHY_LOG="${1#*=}" ;;
    --no-log)     _oniomarchy_no_log=1 ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "unknown option: $1" >&2; echo >&2; usage >&2; exit 2 ;;
  esac
  shift
done

source "$ONIOMARCHY_INSTALL/helpers/ui.sh"
ui_init

# A run that isn't attached to a terminal can't have a live line drawn on
# it, and must not emit cursor escapes into someone's captured log.
if (( ! ONIOMARCHY_VERBOSE )) && ! ui_can_draw; then
  ONIOMARCHY_VERBOSE=1
  _oniomarchy_forced_verbose=1
fi
export ONIOMARCHY_VERBOSE

# --- the log --------------------------------------------------------------

# Always a real file, even under --no-log: the failure excerpt reads back
# from it, so the code path is the same either way and only the cleanup
# differs. ONIOMARCHY_LOG_SHOWN gates whether we tell the operator about
# a path they asked us not to keep.
_oniomarchy_keep_log=1
if (( _oniomarchy_no_log )); then
  ONIOMARCHY_LOG="$(mktemp -t oniomarchy-install.XXXXXXXX)"
  _oniomarchy_keep_log=0
elif [[ -n $ONIOMARCHY_LOG ]]; then
  mkdir -p "$(dirname "$ONIOMARCHY_LOG")"
  ONIOMARCHY_LOG_SHOWN=1
else
  # Outside the repo, deliberately: install logs have been purged from
  # this repo's history once and deleted twice (CLAUDE.md, Layout), and
  # *.log is gitignored so a capture can never be committed.
  _oniomarchy_log_dir="$HOME/.local/state/oniomarchy"
  mkdir -p "$_oniomarchy_log_dir"
  ONIOMARCHY_LOG="$_oniomarchy_log_dir/install-$(date +%Y%m%d-%H%M%S).log"
  ln -sfn "$ONIOMARCHY_LOG" "$_oniomarchy_log_dir/latest.log"
  ONIOMARCHY_LOG_SHOWN=1
fi
: > "$ONIOMARCHY_LOG"
export ONIOMARCHY_LOG ONIOMARCHY_LOG_SHOWN

# One-line channel a running step uses to tell the live line something
# the operator needs to see now (today: pkg.sh's retries). See
# install/helpers/ui.sh's _ui_status_read.
ONIOMARCHY_STATUS="$(mktemp -t oniomarchy-status.XXXXXXXX)"
export ONIOMARCHY_STATUS

_oniomarchy_reached_summary=0

_oniomarchy_cleanup() {
  local code=$1
  ui_cleanup
  # A non-app step failed and `set -e` unwound the run before the
  # summary. Say so, rather than just stopping.
  if (( code != 0 )) && (( ! _oniomarchy_reached_summary )) && \
     [[ -z ${ONIOMARCHY_UI_INTERRUPTED:-} ]]; then
    ui_aborted "${ONIOMARCHY_FAILED_STEP:-}" "$code"
  fi
  if [[ -n ${_oniomarchy_sudo_keepalive:-} ]]; then
    kill "$_oniomarchy_sudo_keepalive" 2>/dev/null || true
  fi
  rm -f "$ONIOMARCHY_STATUS"
  (( _oniomarchy_keep_log )) || rm -f "$ONIOMARCHY_LOG"
}
trap '_oniomarchy_cleanup $?' EXIT
trap 'ui_interrupted; exit 130' INT TERM

_oniomarchy_started=$SECONDS
ui_banner
if [[ -n ${_oniomarchy_forced_verbose:-} ]]; then
  ui_note "No terminal to draw on — showing full output instead."
fi

# --- preflight, then privileges -------------------------------------------

source "$ONIOMARCHY_INSTALL/helpers/logging.sh"
source "$ONIOMARCHY_INSTALL/preflight/all.sh"

# Ask once, up front, before anything goes quiet. `omarchy pkg add` is
# `sudo pacman -S --noconfirm` and `omarchy pkg aur add` is `yay -S
# --noconfirm`, so the password is the only interactive thing in the
# whole run — but in quiet mode its prompt would be swallowed by the log
# and the operator would sit watching a spinner that is waiting on them.
if ! sudo -n true 2>/dev/null; then
  ui_note "This installer needs administrator access to install packages."
  ui_step_stop_live
  sudo -v
fi
# Hold that authorisation for the rest of the run, and stop when we do.
( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 60; done ) &
_oniomarchy_sudo_keepalive=$!

# --- the install ----------------------------------------------------------

source "$ONIOMARCHY_INSTALL/apps/all.sh"
source "$ONIOMARCHY_INSTALL/security/all.sh"
source "$ONIOMARCHY_INSTALL/services/all.sh"
source "$ONIOMARCHY_INSTALL/hooks/all.sh"
source "$ONIOMARCHY_INSTALL/widgets/all.sh"
source "$ONIOMARCHY_INSTALL/trigger/all.sh"
source "$ONIOMARCHY_INSTALL/themes/all.sh"

# --- summary --------------------------------------------------------------

_oniomarchy_failed_count=0
if [[ -n ${ONIOMARCHY_APPS_FAILED:-} ]]; then
  # shellcheck disable=SC2086
  set -- $ONIOMARCHY_APPS_FAILED
  _oniomarchy_failed_count=$#
fi

_oniomarchy_reached_summary=1
ui_summary \
  "${ONIOMARCHY_APPS_OK:-0}" \
  "$_oniomarchy_failed_count" \
  "$(( SECONDS - _oniomarchy_started ))" \
  "${ONIOMARCHY_APPS_FAILED:-}"

[[ -z ${ONIOMARCHY_APPS_FAILED:-} ]]
