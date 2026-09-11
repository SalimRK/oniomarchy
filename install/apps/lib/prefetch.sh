# Fill the pacman cache once, up front, before any app script runs.
#
# The per-app layout trades one dependency resolution for ~79 of them.
# This buys most of that back: a single `pacman -Sw` downloads every
# package the selected leaves name — official repos and [oniomarchy]
# alike — in parallel into /var/cache/pacman/pkg, after which each
# per-app install is a local operation.
#
# Deliberately NON-FATAL. A stalled mirror here must not stop the run —
# that atomic-transaction failure mode is the entire reason this repo
# moved off a single `omarchy pkg add` (see notes/per-app-scripts.md).
# Whatever prefetch fails to fetch, the owning app script downloads on
# its own afterwards, where the cost of a stall is one app instead of
# all of them.
#
# -Sw is download-only: it never installs, never touches the local
# package database beyond the sync it already did, and is safe to
# interrupt.
#
# Scoped to the leaves install.sh actually selected (ONIOMARCHY_SELECTED_
# LEAVES_FILE, written by lib/packs.sh), not the whole apps/ tree — a
# `--pack sdr` run must not download official packages for the other 70+
# apps it isn't going to install. See notes/pack-design.md's "the trap".

# --- download progress ----------------------------------------------------
#
# pacman prints NOTHING while downloading when its stdout is not a tty —
# verified against a real run's log: the step goes straight from
# ":: Retrieving packages..." to silence, with no percent or bar
# characters anywhere in it. So the only honest progress signal is a
# measured one, and this measures bytes rather than counting packages:
# maltego is 206 MiB and theharvester-git is 0.96 MiB, so "12 of 17
# packages" would sit still through the parts that actually take time.
#
# The numerator has to be read as root. pacman 7 downloads into
# /var/cache/pacman/pkg/download-XXXXXX/ directories that are mode 0700,
# so an unprivileged `du` sees none of the bytes in flight. install.sh
# primes sudo with a keepalive for the whole run, so `sudo -n` here never
# prompts; if it somehow cannot, the percentage is simply never shown and
# nothing else changes.
#
# The denominator comes from pacman's own "Total Download Size:" line,
# read back out of the log as it appears — which is why this does not
# need to pipe pacman's output through anything, leaving its exit code
# and its log output exactly as they were.
_oniomarchy_prefetch_progress() {
  local cachedir="$1" baseline="$2" log="$3"
  local total=0 now delta pct tick=0

  # Sleeps in 0.5s steps but only measures every 4th, so `du` still runs at
  # a 2s cadence while a TERM from the caller lands within half a second.
  # Sleeping the full interval instead made every prefetch — including one
  # where nothing needed downloading — stall for two seconds at the `wait`.
  while :; do
    tick=$(( tick + 1 ))
    if (( tick % 4 != 1 )); then
      sleep 0.5
      continue
    fi

    if (( total == 0 )) && [[ -r $log ]]; then
      # "Total Download Size:  602.07 MiB" — the unit is not always MiB,
      # so it is read rather than assumed.
      total=$(grep -m1 '^Total Download Size:' "$log" 2>/dev/null | awk '
        { mult = 1
          if ($5 == "KiB") mult = 1024
          else if ($5 == "MiB") mult = 1024 * 1024
          else if ($5 == "GiB") mult = 1024 * 1024 * 1024
          printf "%d", $4 * mult }')
      [[ -n $total ]] || total=0
    fi

    if (( total > 0 )); then
      now=$(sudo -n du -sb "$cachedir" 2>/dev/null | awk '{print $1}')
      if [[ -n $now ]]; then
        delta=$(( now - baseline ))
        (( delta < 0 )) && delta=0
        (( delta > total )) && delta=$total
        pct=$(( delta * 100 / total ))
        [[ -n ${ONIOMARCHY_STATUS:-} ]] &&
          printf '%d / %d MiB · %d%%' \
            $(( delta / 1048576 )) $(( total / 1048576 )) "$pct" \
            > "$ONIOMARCHY_STATUS" 2>/dev/null || true
      fi
    fi
    sleep 0.5
  done
}

_oniomarchy_prefetch() {
  local -a leaves pkgs
  mapfile -t leaves < "$ONIOMARCHY_SELECTED_LEAVES_FILE"
  (( ${#leaves[@]} == 0 )) && return 0

  # pkg_repo as well as pkg_official: an [oniomarchy] package is just as
  # much a download, and prefetching it here is exactly the same win. The
  # two are collected by one grep because pacman treats them identically
  # — the repository is configured by the time this runs (see
  # install/repo/enable.sh, which install.sh sources first).
  #
  # In the aarch64 fallback (ONIOMARCHY_AUR_FALLBACK) pkg_repo names are
  # AUR packages, not in any sync db, so `pacman -Sw` can't prefetch them
  # ("target not found") — collect only pkg_official there. yay downloads
  # AUR sources at build time in each leaf.
  local _re='official|repo'
  [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]] && _re='official'
  mapfile -t pkgs < <(
    grep -hoP "^\s*pkg_(${_re})\s+\K.*" "${leaves[@]}" |
      tr ' ' '\n' | grep -v '^$' | sort -u
  )

  # aarch64: drop any name no configured repository actually carries.
  #
  # Four core leaves — reverse-engineering/ghidra, password-attacks/john,
  # exploitation/metasploit and privacy/veracrypt — now reach their
  # pkg_official call only through an `else` branch, because on aarch64
  # they substitute an AUR package for a tool Arch never built for the
  # arch. The grep above is line-based and cannot see branches, so it
  # still collects the x86_64-only name and `pacman -Sw` still answers
  # "error: target not found: ghidra" for it. Harmless — this whole step
  # is non-fatal — but it lands in the first twenty lines of the log and
  # makes a run that is working perfectly look like it is already broken.
  #
  # One `pacman -Slq` (every exact name in every configured sync db,
  # ~0.3s) filters them out. Exact names only, because -Slq does not list
  # provides: a hypothetical `pkg_official java-environment` would be
  # dropped from the prefetch too, which costs one uncached download in
  # the leaf that names it and can never cost a failure. And if that
  # command gives nothing back, the list is left exactly as it was rather
  # than silently emptied — a transient pacman failure must not turn the
  # prefetch into a no-op. x86_64 never runs any of this.
  if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
    local _known
    if _known="$(mktemp)"; then
      if pacman -Slq > "$_known" 2>/dev/null && [[ -s $_known ]]; then
        mapfile -t pkgs < <(
          printf '%s\n' "${pkgs[@]}" | grep -xF -f "$_known" || true
        )
      fi
      rm -f "$_known"
    fi
  fi

  (( ${#pkgs[@]} == 0 )) && return 0

  echo "==> Prefetching ${#pkgs[@]} packages into the pacman cache"
  echo "    (non-fatal — anything missed is fetched by its own app script)"

  # Baseline before anything is fetched, so the delta is this run's bytes
  # and not the 2500-odd packages already sitting in the cache.
  local cachedir baseline rc
  cachedir="$(pacman-conf CacheDir 2>/dev/null | head -1)"
  cachedir="${cachedir:-/var/cache/pacman/pkg}"
  baseline="$(sudo -n du -sb "$cachedir" 2>/dev/null | awk '{print $1}')"

  # Poller in the BACKGROUND, pacman in the foreground — deliberately that
  # way round, and not the reverse. Backgrounding the work and polling it
  # with `kill -0` never terminates: a finished-but-unreaped child still
  # answers. install/helpers/ui.sh's spinner learned this the hard way and
  # is shaped the same way for the same reason.
  local progress_pid=""
  if [[ -n $baseline ]]; then
    _oniomarchy_prefetch_progress "$cachedir" "$baseline" "$ONIOMARCHY_LOG" &
    progress_pid=$!
  fi

  sudo pacman -Sw --needed --noconfirm "${pkgs[@]}"
  rc=$?

  if [[ -n $progress_pid ]]; then
    kill "$progress_pid" 2>/dev/null || true
    wait "$progress_pid" 2>/dev/null || true
  fi
  [[ -n ${ONIOMARCHY_STATUS:-} ]] && : > "$ONIOMARCHY_STATUS"

  if (( rc != 0 )); then
    echo "==> Prefetch incomplete — continuing; each app will fetch what it needs" >&2
    # Non-zero so the caller can SAY it was incomplete. Still not fatal:
    # install/apps/all.sh runs this step in a branch that reports the
    # failure and carries on. Returning 0 here instead would leave the
    # operator looking at a green tick for a step that half-worked.
    return 1
  fi

  return 0
}

_oniomarchy_prefetch
