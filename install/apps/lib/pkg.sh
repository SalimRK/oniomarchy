# Package-install helpers shared by every leaf under install/apps/.
#
# App scripts call pkg_official / pkg_aur rather than `omarchy pkg add`
# directly, so retry policy, AUR build-environment hygiene, and failure
# reporting live in exactly one place instead of being re-decided 79
# times.
#
# Sourced into each leaf's own bash process by run_app (install/apps/all.sh),
# not inherited — shell functions don't cross a process boundary the way
# exported variables do.

# --- retry policy ---------------------------------------------------------
#
# Retry ONLY a transfer failure. A broken PKGBUILD or an unresolvable
# dependency fails identically every time, so retrying it just burns the
# user's time and buries the real error under two more copies of itself.
#
# Transfer failures are worth retrying here because Omarchy ships a
# single-mirror /etc/pacman.d/mirrorlist — stable-mirror.omarchy.org is
# the Include for core, extra AND multilib — so pacman has no fallback
# server to fall back to when that host stalls. A tester on a weak link
# hits this constantly; see notes/per-app-scripts.md for the log that
# prompted all of this.
_oniomarchy_is_transfer_failure() {
  grep -qE \
    'failed retrieving file|failed to retrieve some files|Operation too slow|Could not resolve host|Connection timed out|error: failed to commit transaction \(failed to retrieve some files\)|request failed: Get|unexpected EOF|context deadline exceeded|Client\.Timeout exceeded|TLS handshake timeout|i/o timeout|no such host|connection reset by peer' \
    "$1"
}

# Deliberately NOT matched: yay's "No AUR package found for <x>" and
# "no package found for targets". Those are the *consequence* lines yay
# prints after a failed RPC query, and they are also exactly what it
# prints when a package has genuinely been deleted from the AUR. Matching
# them would retry a real removal three times. The request-failure lines
# above them are the honest signal, and they are in the same captured
# output, so nothing is lost by ignoring the summary.

# Publish a short note for the live line to show (install/helpers/ui.sh
# reads this file every spinner tick). Retries otherwise happen entirely
# in the log, which in quiet mode is off-screen — a stalled mirror would
# look exactly like a frozen spinner for up to three attempts, which is
# the very failure this repo restructured around.
_oniomarchy_status() {
  [[ -n ${ONIOMARCHY_STATUS:-} ]] || return 0
  printf '%s' "$1" > "$ONIOMARCHY_STATUS" 2>/dev/null || true
}

_oniomarchy_pkg_install() {
  local kind="$1" attempts="$2"
  shift 2

  local log rc attempt=1
  log=$(mktemp) || return 1

  while :; do
    # tee so the user still sees pacman/yay output live, while the copy
    # in $log lets us tell a stalled download apart from a real build
    # failure. PIPESTATUS because the pipe's exit code is tee's, not the
    # installer's.
    if [[ $kind == official ]]; then
      omarchy pkg add "$@" 2>&1 | tee "$log"
    else
      omarchy pkg aur add "$@" 2>&1 | tee "$log"
    fi
    rc=${PIPESTATUS[0]}

    (( rc == 0 )) && break
    (( attempt >= attempts )) && break
    _oniomarchy_is_transfer_failure "$log" || break

    echo "==> Transfer failure — retrying ($attempt/$(( attempts - 1 ))): $*" >&2
    _oniomarchy_status "$1 · retry $attempt/$(( attempts - 1 ))"
    sleep 3
    attempt=$(( attempt + 1 ))
  done

  rm -f "$log"
  _oniomarchy_status ""
  return "$rc"
}

# pkg_official <packages...> — official repos, two retries.
pkg_official() {
  _oniomarchy_pkg_install official 3 "$@"
}

# pkg_aur <packages...> — AUR, one retry.
#
# Cleans mise out of PATH first, always. Every AUR build in this repo
# needs that (see lib/clean-build-path.sh for what happens when it
# doesn't), and doing it here instead of asking each leaf to remember
# means a new AUR app can't silently inherit the bug that baked a mise
# shebang into wfuzz's entry points — notes/install-issues.md.
pkg_aur() {
  _oniomarchy_clean_build_path
  _oniomarchy_pkg_install aur 2 "$@"
}

# Idempotent; safe to call from several places in one leaf.
_oniomarchy_clean_build_path() {
  [[ -n ${_ONIOMARCHY_PATH_CLEANED:-} ]] && return 0
  source "$ONIOMARCHY_INSTALL/apps/lib/clean-build-path.sh"
  export _ONIOMARCHY_PATH_CLEANED=1
}

# retry_transfer <command...> — run an arbitrary installer command under
# the same retry policy pkg_official/pkg_aur use.
#
# For the rare app that cannot go through those wrappers because it needs
# a flag `omarchy pkg aur add` does not expose — today only wfuzz, which
# needs `yay -S --rebuild` to force a rebuild rather than skipping an
# already-installed package. Without this, such an app silently opts out
# of retrying and a transient AUR RPC failure fails it outright.
retry_transfer() {
  local log rc attempt=1
  log=$(mktemp) || return 1

  while :; do
    "$@" 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}

    (( rc == 0 )) && break
    (( attempt >= 3 )) && break
    _oniomarchy_is_transfer_failure "$log" || break

    echo "==> Transfer failure — retrying ($attempt/2): $*" >&2
    _oniomarchy_status "${1##*/} · retry $attempt/2"
    sleep 5
    attempt=$(( attempt + 1 ))
  done

  rm -f "$log"
  _oniomarchy_status ""
  return "$rc"
}
