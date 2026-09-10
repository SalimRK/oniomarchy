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
    elif [[ $mode == aur ]]; then
      # --ignorearch: several AUR PKGBUILDs still declare arch=('x86_64')
      # for what is portable source (dirb, steghide, gophish, autopsy,
      # sleuthkit-java, eyewitness-git) — it builds on aarch64, the tag
      # just predates it. A genuinely x86_64-only prebuilt binary has no
      # source_aarch64 and still fails cleanly at fetch. Called directly,
      # not via `omarchy pkg aur add`, because that wrapper can't pass
      # makepkg flags. yay/makepkg run as the invoking user (never root).
      yay -S --needed --noconfirm --mflags --ignorearch "$@" 2>&1 | tee "$log"
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

  # `omarchy pkg add` makes this check itself; the repo and aur paths call
  # pacman/yay directly, so they have to make it too — neither reliably
  # returns non-zero for a target it silently did nothing about.
  if (( rc == 0 )) && [[ $mode == repo || $mode == aur ]]; then
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

# pkg_aur <packages...> — build from the AUR. Only reached in the aarch64
# fallback (pkg_repo routes here when ONIOMARCHY_AUR_FALLBACK is set); on
# x86_64 nothing calls it.
#
# Runs `yay` (Omarchy's shipped helper; paru is not installed) directly
# rather than through `omarchy pkg aur add`, because that wrapper can't
# pass the `--ignorearch` makepkg flag the fallback needs (see the aur
# branch of _oniomarchy_pkg_install). yay runs makepkg as the invoking
# user, and neither yay nor makepkg may run as root — so this is
# deliberately NOT sudo, and the leaf already runs as the user. The
# post-install `pacman -Q` check that `omarchy pkg aur add` would have
# done is made by _oniomarchy_pkg_install for aur mode instead.
#
# Cleans mise out of PATH first (lib/clean-build-path.sh), exactly as the
# pre-2026-09-06 pkg_aur did: an AUR build() must use the system toolchain,
# not a version-manager shim. One retry — a transient AUR RPC/download
# stall is worth retrying; a build failure is not (see the retry policy).
pkg_aur() {
  _oniomarchy_clean_build_path

  # Go's linker (and makepkg's own scratch) write to $TMPDIR, which
  # defaults to /tmp — a 2 GB tmpfs on Omarchy. Linking a large Go binary
  # overflows it with "no space left on device" (nuclei hit this; sliver
  # would too), even though the package itself builds in ~/.cache/yay on
  # the roomy root filesystem. Point temp at /var/tmp, which is
  # disk-backed and on that same filesystem. `local` scopes the export to
  # this build — yay inherits it, the rest of the run does not — so the
  # installer's own mktemp calls keep using /tmp as before.
  local TMPDIR
  export TMPDIR=/var/tmp

  _oniomarchy_pkg_install aur 2 "$@"
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
# On x86_64 a package that [oniomarchy] does not serve fails the leaf
# rather than being built from the AUR. That is the point: there is no
# silent hour of compiling. In practice this only fires on drift — a leaf
# naming something that was never published, or was dropped from the repo
# — and it names the package so the drift is obvious rather than mysterious.
#
# The one exception is the aarch64 fallback (ONIOMARCHY_AUR_FALLBACK, set
# in install.sh): [oniomarchy] has no aarch64 tree, so there every package
# routes to pkg_aur. The blanket "no AUR" the AUR path was removed for
# (2026-09-06) still holds on x86_64, which is the arch it was decided for.
pkg_repo() {
  # aarch64: no [oniomarchy] to serve these — build from the AUR instead.
  # On x86_64 this branch is never taken and the signed-binaries-only path
  # below is unchanged.
  if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
    pkg_aur "$@"
    return
  fi

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
