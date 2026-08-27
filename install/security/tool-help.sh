#!/usr/bin/env bash
#
# Show a security tool's own usage/help, then hand off to an interactive
# shell — the launch target for every CLI entry in the Security menu.
# Installed to /usr/local/bin/oniomarchy-tool-help by
# install/security/install-scripts.sh, invoked as:
#   omarchy-launch-tui bash -c 'oniomarchy-tool-help <binary>; exec bash'
#
# Why: clicking a tool in the menu used to run it bare, which for most
# pentest tools means either a wall of "missing required argument", a
# hang on an interactive prompt, or — for anything touching a raw socket
# (bettercap, the aircrack-ng suite) — an immediate "Permission Denied"
# with no hint of what to do next. Showing usage first and leaving a
# ready shell is the useful thing: you see the flags, then type the real
# command.
#
# Help flags are discovered at run time, not hardcoded per tool — the
# same "verify, don't guess" rule verify-binaries.sh follows for binary
# names (see CLAUDE.md). Measured across the 289 CLI commands this menu
# currently generates: 255 print usage from a flag, 6 have only a man
# page, 3 need root even to print usage, and 25 have neither and are
# started instead.
#
# Four outcomes, in order of preference:
#   1. a help flag prints usage            -> show it
#   2. only root can print usage           -> re-run under sudo
#   3. no flag works but a man page exists -> show the man page
#   4. none of the above                   -> run the tool (it's a server
#      or an interactive framework; running IS the useful action)
#
# The sudo path prompts for a password in this terminal — the same
# sudo-in-a-real-terminal pattern service-confirm-action.sh uses for the
# SSH/RDP entries, per CLAUDE.md's privilege-escalation rule (sudo for
# terminal-visible commands, pkexec only for GUI actions with no terminal
# to prompt in).

set -uo pipefail

tool="${1:?usage: oniomarchy-tool-help <binary>}"

if ! command -v "$tool" >/dev/null 2>&1; then
  echo "oniomarchy-tool-help: '$tool' is not on PATH — is its package still installed?" >&2
  exit 127
fi

probe_tmp=$(mktemp)
trap 'rm -f "$probe_tmp"' EXIT

# Does this output look like real usage text, rather than an error?
looks_like_help() {
  local out="$1"
  grep -qiE '(^|[^[:alnum:]])usage[:[:space:]]|^[[:space:]]*(options|commands|synopsis|usage)\b' <<<"$out" && return 0
  (( $(grep -cE '^[[:space:]]*-{1,2}[A-Za-z0-9]' <<<"$out") >= 3 ))
}

# Did the tool refuse for lack of privileges? Only meaningful when the
# output ISN'T already help — several tools' genuine help text mentions
# needing root (impacket's smbserver.py explains you must be root to bind
# port 445), and that must not trigger a spurious sudo prompt.
needs_root() {
  grep -qiE 'run (it )?as root|must be (run as )?root|requires? root|root privile|permission denied|operation not permitted|you (need|have) to be root' <<<"$1"
}

# Did the tool explicitly reject the flag we just passed? Several tools
# (airserv-ng, canlogserver) answer an unknown flag by printing the
# rejection AND then dumping their usage, which is still readable but
# leads with a spurious error — so a rejected flag is only used as a last
# resort, after the flags the tool actually accepts have been tried.
rejected_flag() {
  grep -qiE 'unrecognized option|invalid option|unknown option|illegal option|unknown flag|bad option|unknown shorthand' <<<"$1"
}

# Probe with stdin closed, so a tool that ignores the flag and goes
# straight to an interactive prompt (seproxy, sniff.py) hits EOF and
# exits instead of hanging this terminal before the user gets a shell.
#
# Output goes to a temp file rather than through a pipe on purpose: a
# tool that forks and keeps stdout open (canlogserver) would hold a pipe
# open past its own timeout, wedging the command substitution
# indefinitely. A file has no such writer to wait on.
#
# 8s is deliberate headroom, not a guess: every tool in this menu that
# answers a help flag does so in a second or less, JVM- and Ruby-backed
# ones (msfconsole, ghidra-analyzeHeadless, jadx) included.
PROBE_TIMEOUT=8
probe() {
  local rc
  : > "$probe_tmp"
  timeout -s KILL "$PROBE_TIMEOUT" "$@" </dev/null >"$probe_tmp" 2>&1
  rc=$?
  cat "$probe_tmp"
  return $rc
}

# This machine's own reachable addresses. Shown on every entry because a
# pentest menu is exactly where you keep needing your own IP — LHOST for
# a payload, the bind address of a listener, the URL to hand a target.
show_addresses() {
  local addrs
  addrs=$(ip -4 -o addr show scope global 2>/dev/null |
    awk '{split($4,a,"/"); printf "%s %s   ", $2, a[1]}' |
    sed 's/[[:space:]]*$//')
  [[ -n $addrs ]] && printf '\033[2mthis host: %s\033[0m\n' "$addrs"
  return 0
}

help_out=""
help_flag=""
root_flag=""
ignores_flags=0
# Usage text the tool printed only after complaining about the flag —
# kept as a fallback in case no flag is accepted cleanly.
fallback_out=""
fallback_flag=""

# Returns 0 once clean usage is in hand, 1 to keep looking.
try_flag() {
  local flag="$1" out rc
  out=$(probe "$tool" "$flag")
  rc=$?

  # Timed out: the tool ignored the argument and started doing its actual
  # job. Trying more would burn another timeout each and leave more
  # processes running.
  if (( rc == 124 || rc == 137 )); then
    ignores_flags=1
    return 1
  fi

  if looks_like_help "$out"; then
    if rejected_flag "$out"; then
      [[ -z $fallback_flag ]] && { fallback_out="$out"; fallback_flag="$flag"; }
    else
      help_out="$out"
      help_flag="$flag"
      return 0
    fi
  elif [[ -z $root_flag ]] && needs_root "$out"; then
    root_flag="$flag"
  fi
  return 1
}

# --help and -h are unambiguously flags: safe to pass to anything.
for flag in --help -h; do
  try_flag "$flag" && break
  (( ignores_flags )) && break
done

# Bare `help` is a subcommand, not a flag, so a tool that doesn't know it
# treats it as a positional argument — canlogserver reads it as the name
# of a CAN interface and starts serving. Only reach for it when the two
# real flags produced nothing usable at all.
if [[ -z $help_flag && -z $fallback_flag ]] && (( ignores_flags == 0 )); then
  try_flag help || true
fi

if [[ -z $help_flag && -n $fallback_flag ]]; then
  help_out="$fallback_out"
  help_flag="$fallback_flag"
fi

# Every path prints the exact command it ran, in the same place and the
# same shape — including the sudo and man ones, where what actually ran
# isn't just "<tool> <flag>". Prefixed with `$ ` so it reads as a command
# and can be copied straight back out.
show_cmd() {
  printf '\033[2m$ %s\033[0m\n' "$1"
}

printf '\n\033[1m%s\033[0m\n' "$tool"

# Nothing here is piped through a pager on purpose. `less` (even with -F)
# holds the terminal on any help longer than one screen, so you'd have to
# press q before reaching the shell this launcher exists to hand you.
# Printing straight out means the shell prompt follows immediately and
# the terminal's own scrollback keeps the long ones.
if [[ -n $help_flag ]]; then
  show_cmd "$tool $help_flag"
  echo
  printf '%s\n' "$help_out"

elif [[ -n $root_flag ]]; then
  show_cmd "sudo $tool $root_flag"
  echo
  echo "This tool won't print its usage as a normal user — re-running with sudo."
  echo
  sudo -- "$tool" "$root_flag" </dev/null 2>&1

elif (( ignores_flags == 0 )) && man -w "$tool" >/dev/null 2>&1; then
  # No help flag, but a real man page exists (dirb, nikto, rtl_power and
  # friends only print usage when run bare, which would mean starting the
  # tool just to read its arguments).
  #
  # Piped through `col -bx` for two reasons at once: man sees a non-tty
  # and so skips its own pager (same no-pager rule as above), and col
  # strips the backspace-overstrike man uses for bold/underline, which
  # renders as "NNAAMMEE" without a pager to interpret it. Plain text,
  # no pager, every time. (col is util-linux — always present.)
  show_cmd "man $tool"
  echo
  man "$tool" 2>/dev/null | col -bx

else
  # Nothing to show: no help flag, no man page — either a server that
  # just starts listening (bcmserver) or an interactive framework that
  # owns the whole terminal (setoolkit, rsf). For these, running IS the
  # useful action, so hand the terminal over instead of printing a dead
  # end. Addresses go first: once the tool takes over, this is the last
  # chance to read them, and a listener is exactly when they're wanted.
  show_cmd "$tool"
  printf '\033[2m(no help flag or man page — starting it)\033[0m\n'
  show_addresses
  echo
  "$tool"
fi

printf '\n\033[2m-- shell ready; run %s with real arguments --\033[0m\n' "$tool"
show_addresses
echo
