# Package-install helpers shared by every leaf under install/apps/.
#
# App scripts call pkg_official / pkg_repo rather than `omarchy pkg add`
# directly, so retry policy and failure reporting live in exactly one
# place instead of being re-decided 80 times.
#
# Sourced into each leaf's own bash process by run_app (install/apps/all.sh),
# not inherited — shell functions don't cross a process boundary the way
# exported variables do.
#
# THERE IS NO AUR PATH ANY MORE (2026-09-06). Every package this install
# needs is either in the official repos or published as a signed binary
# in [oniomarchy]; pkg_aur and retry_transfer were removed along with the
# last three AUR-only leaves (python-garak, savvycan, xrdp), which were
# dropped from the toolkit entirely. See install/repo/enable.sh and the
# packaging repo's notes/handoff-to-main-repo.md.

# --- retry policy ---------------------------------------------------------
#
# Retry ONLY a transfer failure. A missing package or an unresolvable
# dependency fails identically every time, so retrying it just burns the
# user's time and buries the real error under two more copies of itself.
#
# Transfer failures are worth retrying because Omarchy ships a
# single-mirror /etc/pacman.d/mirrorlist — stable-mirror.omarchy.org is
# the Include for core, extra AND multilib — so pacman has no fallback
# server to fall back to when that host stalls. A tester on a weak link
# hits this constantly; see notes/per-app-scripts.md for the log that
# prompted all of this. [oniomarchy] is likewise a single origin.
_oniomarchy_is_transfer_failure() {
  grep -qE \
    'failed retrieving file|failed to retrieve some files|Operation too slow|Could not resolve host|Connection timed out|error: failed to commit transaction \(failed to retrieve some files\)|unexpected EOF|Client\.Timeout exceeded|TLS handshake timeout|i/o timeout|no such host|connection reset by peer' \
    "$1"
}

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
  local mode="$1" attempts="$2"
  shift 2

  local log rc attempt=1
  log=$(mktemp) || return 1

  while :; do
    # tee so the user still sees pacman output live, while the copy in
    # $log lets us tell a stalled download apart from a real failure.
    # PIPESTATUS because the pipe's exit code is tee's, not pacman's.
    if [[ $mode == repo ]]; then
      sudo pacman -S --needed --noconfirm "$@" 2>&1 | tee "$log"
    else
      omarchy pkg add "$@" 2>&1 | tee "$log"
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

  # `omarchy pkg add` makes this check itself; the repo path has to make
  # it too, because pacman does not always return non-zero for a target it
  # silently did nothing about.
  if (( rc == 0 )) && [[ $mode == repo ]]; then
    local pkg
    for pkg in "$@"; do
      if ! pacman -Q "$pkg" >/dev/null 2>&1; then
        echo "oniomarchy: package '$pkg' did not install" >&2
        rc=1
      fi
    done
  fi

  return "$rc"
}

# pkg_official <packages...> — core/extra/multilib, two retries.
#
# Goes through `omarchy pkg add`, which is presence-gated: it runs pacman
# only when something is actually missing. That is the right conservative
# behaviour for official packages — upgrading one on its own is a partial
# upgrade, which Arch does not support, and keeping system packages
# current is `omarchy update`'s job, not this installer's.
pkg_official() {
  _oniomarchy_pkg_install official 3 "$@"
}

# oniomarchy_repo_has <package> — is <package> served by [oniomarchy]?
#
# Reads the list install/repo/enable.sh wrote. A leaf can use this to ask
# the question directly; pkg_repo below is the usual way.
oniomarchy_repo_has() {
  [[ -s ${ONIOMARCHY_REPO_PKGS:-} ]] || return 1
  grep -qxF "$1" "$ONIOMARCHY_REPO_PKGS"
}

# pkg_repo <packages...> — install prebuilt, signed binaries from
# [oniomarchy].
#
# Mechanically this is pkg_official: `omarchy pkg add` is `pacman -S
# --needed --noconfirm`, which resolves against every configured
# repository, and [oniomarchy] is configured by the time any leaf runs.
# The separate name is not decoration — it records at each call site
# which packages this project builds and signs itself, and it is what
# makes the check below possible.
#
# **This is the one place in the repo that calls pacman directly instead
# of going through the `omarchy` CLI, and it is deliberate.** `omarchy pkg
# add` is gated by `omarchy-pkg-missing`, which asks whether a package is
# PRESENT, not whether it is current:
#
#     if omarchy-pkg-missing "$@"; then      # false if all are installed
#       pacman -S --noconfirm --needed "$@"  # ...so this never runs
#     fi
#
# That is fine for its own purpose and fatal for ours. Found on the first
# real run, 2026-09-06: the installer downloaded 602 MiB of signed
# binaries and installed almost none of it, because every package was
# already present as an older AUR build. maltego stayed at 4.8.1 with
# 4.12.1 sitting in the cache. A fresh machine was unaffected — nothing is
# installed there — so the failure was invisible exactly on the machines
# that already had the problem this repository exists to solve.
#
# `--needed` still makes this idempotent: a package already at the
# repository's version is skipped. It just stops being blind to versions.
# Yes, a targeted `pacman -S` is formally a partial upgrade; these are our
# own packages, built against current Arch in a clean chroot, and it is
# exactly what `yay -S` did here before.
#
# A package that [oniomarchy] does not serve fails the leaf rather than
# being built from the AUR. That is the point: there is no silent hour of
# compiling. In practice this only fires on drift — a leaf naming
# something that was never published, or was dropped from the repo — and
# it names the package so the drift is obvious rather than mysterious.
pkg_repo() {
  local p
  local -a missing=()
  for p in "$@"; do
    oniomarchy_repo_has "$p" || missing+=("$p")
  done

  if (( ${#missing[@]} > 0 )); then
    echo "oniomarchy: not served by [oniomarchy]: ${missing[*]}" >&2
    echo "  This install uses signed binaries only and does not build from the AUR." >&2
    echo "  Either publish the package from the oniomarchy-pkgs project, or drop" >&2
    echo "  this leaf. See that project's notes/runbook-add-package.md." >&2
    return 1
  fi

  _oniomarchy_pkg_install repo 3 "$@"
}

# Idempotent; safe to call from several places in one leaf.
#
# Still here for hexstrike-ai, the one leaf that is not a package at all
# (git clone + venv) and so invokes python3/pip directly — exactly the
# situation lib/clean-build-path.sh exists for. Package builds no longer
# happen on the user's machine, so nothing else needs it.
_oniomarchy_clean_build_path() {
  [[ -n ${_ONIOMARCHY_PATH_CLEANED:-} ]] && return 0
  source "$ONIOMARCHY_INSTALL/apps/lib/clean-build-path.sh"
  export _ONIOMARCHY_PATH_CLEANED=1
}
