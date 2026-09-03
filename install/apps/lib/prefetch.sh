# Fill the pacman cache once, up front, before any app script runs.
#
# The per-app layout trades one dependency resolution for ~79 of them.
# This buys most of that back: a single `pacman -Sw` downloads every
# official package in parallel into /var/cache/pacman/pkg, after which
# each per-app install is a local operation.
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

_oniomarchy_prefetch() {
  local -a leaves pkgs
  mapfile -t leaves < "$ONIOMARCHY_SELECTED_LEAVES_FILE"
  (( ${#leaves[@]} == 0 )) && return 0

  mapfile -t pkgs < <(
    grep -hoP '^\s*pkg_official\s+\K.*' "${leaves[@]}" |
      tr ' ' '\n' | grep -v '^$' | sort -u
  )

  (( ${#pkgs[@]} == 0 )) && return 0

  echo "==> Prefetching ${#pkgs[@]} official packages into the pacman cache"
  echo "    (non-fatal — anything missed is fetched by its own app script)"

  if ! sudo pacman -Sw --needed --noconfirm "${pkgs[@]}"; then
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
