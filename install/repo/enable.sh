# Enable [oniomarchy] — the signed binary package repository — and record
# what it serves.
#
# This is a HARD REQUIREMENT, not a best-effort step. Every non-official
# package in this install now comes from [oniomarchy] as a prebuilt,
# signed binary; there is no AUR fallback, deliberately (user decision,
# 2026-09-06). Falling back would mean a user whose repo is unreachable
# silently spends an hour compiling with no idea why — so this fails
# here instead, at the one point in the run where nothing has been
# installed, downloaded or built yet.
#
# The step is a plain run_step, so a failure aborts install.sh under
# `set -e` and ui_aborted names it. That ordering is the whole design:
# install.sh sources this before apps/all.sh, whose very first act is to
# prefetch ~80 packages.
#
# THE SCRIPT IS INVOKED, NEVER COPIED. bin/strap.sh lives in the sibling
# oniomarchy-pkgs project, and every value in it — the server URL, the
# SigLevel, and above all the signing-key fingerprint that is the trust
# anchor for this entire repository — is a decision made there. Copying
# the fingerprint into a second repo means a key rotation has two places
# to miss. Nothing in this file names any of those values.

oniomarchy_repo_name=oniomarchy

[[ -n ${ONIOMARCHY_REPO_PKGS:-} ]] || {
  echo "oniomarchy: ONIOMARCHY_REPO_PKGS is not set — this step must run from install.sh" >&2
  exit 1
}

# aarch64: [oniomarchy] serves x86_64 only, so strap.sh's `Server =
# $REPO_URL/$arch` would 404 on `pacman -Sy` (issue #1). There is no repo
# to enable and nothing to record — leave ONIOMARCHY_REPO_PKGS the empty
# file install.sh created, so oniomarchy_repo_has answers "no" for every
# package and pkg_repo builds it from the AUR instead (see lib/pkg.sh).
# exit 0, not return: run_step forks this step into its own process.
if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
  echo "==> AUR fallback ($(uname -m)) — [$oniomarchy_repo_name] is x86_64-only"

  # A prior x86_64-era run, or an earlier failed attempt, can leave the
  # [oniomarchy] block in pacman.conf pointing at an aarch64 tree that
  # 404s. That is NOT harmless: with a configured-but-unsynced repo,
  # pacman fails every transaction with "could not find database", so
  # official installs and yay's final `pacman -U` both break. Remove it
  # (strap.sh --remove is the canonical, tested undo, and ends with a
  # `pacman -Sy` that leaves the other repos synced and healthy).
  if grep -q "^\[$oniomarchy_repo_name\]" /etc/pacman.conf 2>/dev/null; then
    oniomarchy_strap=""
    for oniomarchy_candidate in \
      "${ONIOMARCHY_STRAP:-}" \
      "$ONIOMARCHY_INSTALL/repo/strap.sh"
    do
      [[ -n $oniomarchy_candidate && -f $oniomarchy_candidate ]] || continue
      oniomarchy_strap="$oniomarchy_candidate"
      break
    done
    unset oniomarchy_candidate
    if [[ -n $oniomarchy_strap ]]; then
      echo "==> Removing the stale [$oniomarchy_repo_name] block (it cannot work on $(uname -m))"
      sudo bash "$oniomarchy_strap" --remove
    else
      echo "oniomarchy: [$oniomarchy_repo_name] is configured but strap.sh is missing to remove it" >&2
      echo "  Remove the [$oniomarchy_repo_name] block from /etc/pacman.conf by hand, then re-run." >&2
    fi
    unset oniomarchy_strap
  fi

  # AUR builds need the base toolchain — dirb's PKGBUILD calls `patch`,
  # others need make/gcc/fakeroot. yay assumes base-devel is present and
  # Omarchy does not ship all of it. Install the group directly (not via
  # `omarchy pkg add`, whose `pacman -Q` verify can't check a group name).
  echo "==> Ensuring base-devel for AUR builds"
  sudo pacman -S --needed --noconfirm base-devel

  exit 0
fi

# --- 1. configure the repository, unless it already is -------------------

if pacman-conf --repo-list 2>/dev/null | grep -qx "$oniomarchy_repo_name"; then
  echo "==> [$oniomarchy_repo_name] is already configured in pacman.conf"
else
  # strap.sh ships in this repo (install/repo/strap.sh), so a plain clone
  # can install with no second checkout — that was the whole point of
  # moving it here (2026-09-07). $ONIOMARCHY_STRAP still wins, for anyone
  # deliberately pointing at a different copy.
  oniomarchy_strap=""
  for oniomarchy_candidate in \
    "${ONIOMARCHY_STRAP:-}" \
    "$ONIOMARCHY_INSTALL/repo/strap.sh"
  do
    [[ -n $oniomarchy_candidate && -f $oniomarchy_candidate ]] || continue
    oniomarchy_strap="$oniomarchy_candidate"
    break
  done
  unset oniomarchy_candidate

  if [[ -z $oniomarchy_strap ]]; then
    # This should be unreachable — the script is tracked in this repo — so
    # if it fires, the checkout itself is incomplete or corrupt.
    cat >&2 <<MISSING
oniomarchy: [oniomarchy] is not configured, and strap.sh is missing.

Expected it at: $ONIOMARCHY_INSTALL/repo/strap.sh

That file ships with this repository, so a missing one means an
incomplete checkout. Re-clone, or point at a copy explicitly:

  ONIOMARCHY_STRAP=/path/to/strap.sh ./install.sh
MISSING
    exit 1
  fi

  echo "==> Enabling [$oniomarchy_repo_name] via $oniomarchy_strap"
  # Root, because it edits /etc/pacman.conf and pacman's keyring.
  # install.sh primed sudo before anything went quiet, so this does not
  # prompt from behind a spinner.
  sudo bash "$oniomarchy_strap"
  unset oniomarchy_strap
fi

# --- 2. record what it serves --------------------------------------------

# Written to a file rather than exported, because lib/pkg.sh is sourced
# into each app leaf's own bash process — a variable set here would not
# survive the process boundary, and asking pacman once per leaf would
# ask it ~80 times.
if ! pacman -Sl "$oniomarchy_repo_name" > /dev/null 2>&1; then
  # Configured but never synced (or the sync database was cleaned out).
  # `omarchy pkg add` is `pacman -S` with no -y, so a missing database
  # would otherwise surface much later as "target not found".
  echo "==> No $oniomarchy_repo_name sync database yet — syncing"
  sudo pacman -Sy
fi

pacman -Sl "$oniomarchy_repo_name" | awk '{print $2}' | sort -u > "$ONIOMARCHY_REPO_PKGS"

oniomarchy_repo_count=$(grep -c . "$ONIOMARCHY_REPO_PKGS" || true)
if (( oniomarchy_repo_count == 0 )); then
  echo "oniomarchy: [$oniomarchy_repo_name] is configured but serves no packages." >&2
  echo "  Check the server is reachable, then re-run. See the packaging repo's" >&2
  echo "  notes/handoff-to-main-repo.md." >&2
  exit 1
fi

echo "==> [$oniomarchy_repo_name] serves $oniomarchy_repo_count packages"
unset oniomarchy_repo_count oniomarchy_repo_name
