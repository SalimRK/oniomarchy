#!/usr/bin/env bash
# Configure this machine to use the [oniomarchy] binary package repository.
#
# Usage:  sudo install/repo/strap.sh            # add the repo
#         sudo install/repo/strap.sh --remove   # undo everything this script did
#
# This is the single canonical copy (moved here from the packaging project
# 2026-09-07 so a clone of this repo can install with no second checkout).
# It ships WITH the installer on purpose: install/repo/enable.sh runs it.
# The signing-key fingerprint below is the trust anchor and lives in
# exactly ONE place — here. On a key rotation, this is the one file to
# update; do not create a second copy.
#
# This is the sequence that was run by hand and verified end to end on
# 2026-09-06, including both deliberate-failure tests. It is written to
# be idempotent: running it twice is a no-op, not a duplicate repo entry.
#
# It solves the chicken-and-egg every signed repository has: a machine
# that does not yet trust our key cannot verify the package that installs
# our key. So the key is imported directly here, and the
# `oniomarchy-keyring` package takes over from there — which is what
# makes the 2029 key rotation an ordinary `pacman -Syu` rather than a
# support thread.
set -euo pipefail

REPO_NAME=oniomarchy
REPO_URL=https://pkgs.oniomarchy.com
KEY_URL="$REPO_URL/oniomarchy.gpg"
PACMAN_CONF=/etc/pacman.conf

# Hard-coded on purpose. This is the trust anchor, and it is the reason
# fetching a key over HTTPS is safe: without this check, whoever controls
# the domain, the CDN, or any CA in the chain could hand you a different
# key and you would trust it. TLS proves you reached the server; only the
# fingerprint proves the key is ours.
#
# If this value ever needs to change, that is a key rotation, and it must
# be announced out of band — not shipped quietly in a script update.
FPR=0F5F9214F312B067ECBF1DF125E2C00AA6340BD0

# Deliberately DatabaseRequired, not the DatabaseOptional in the original
# design doc. Signing the database and then declining to verify it leaves
# the downgrade attack wide open: swap the database, point a user at a
# real, correctly-signed, KNOWN-VULNERABLE version of one of our
# packages, and every individual signature still checks out. Verified
# 2026-09-06 that a tampered database is refused with this setting.
SIGLEVEL="Required DatabaseRequired"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "must run as root: sudo $0 ${1:-}"

for cmd in pacman pacman-key gpg curl; do
  command -v "$cmd" >/dev/null || die "required command not found: $cmd"
done

# ---------------------------------------------------------------------
# --remove: undo everything, in reverse order
# ---------------------------------------------------------------------
if [[ "${1:-}" == "--remove" ]]; then
  info "removing [$REPO_NAME]"

  if pacman -Qq oniomarchy-keyring >/dev/null 2>&1; then
    info "removing the oniomarchy-keyring package"
    pacman -R --noconfirm oniomarchy-keyring
  fi

  if grep -q "^\[$REPO_NAME\]" "$PACMAN_CONF"; then
    info "removing the [$REPO_NAME] block from $PACMAN_CONF"
    cp -a "$PACMAN_CONF" "$PACMAN_CONF.bak.$(date +%Y%m%d%H%M%S)"
    # Delete from the section header to the line before the next section
    # header, or to end of file if it is the last section.
    sed -i "/^\[$REPO_NAME\]\$/,/^\[/{ /^\[$REPO_NAME\]\$/d; /^\[/!d }" "$PACMAN_CONF"

    # Drop the ONE blank separator line this script added before the
    # block. Without it, install → remove → install leaves an extra blank
    # line behind each cycle and $PACMAN_CONF grows a tail of them.
    #
    # Exactly one, not all trailing blanks: many pacman.conf files
    # already end with a blank line, and eating it would mean --remove
    # does not restore the file it was given. A blank before a
    # *following* section is untouched — it is still a separator.
    if [[ -s "$PACMAN_CONF" && -z "$(tail -n1 "$PACMAN_CONF")" ]]; then
      sed -i '$d' "$PACMAN_CONF"
    fi
  fi

  if pacman-key --list-keys "$FPR" >/dev/null 2>&1; then
    info "removing the signing key from pacman's keyring"
    pacman-key --delete "$FPR" || warn "could not delete key $FPR"
  fi

  rm -f "/var/lib/pacman/sync/$REPO_NAME.db" "/var/lib/pacman/sync/$REPO_NAME.db.sig" \
        "/var/lib/pacman/sync/$REPO_NAME.files" "/var/lib/pacman/sync/$REPO_NAME.files.sig"

  info "resyncing"
  pacman -Sy
  info "done — [$REPO_NAME] removed. A backup of $PACMAN_CONF was kept."
  exit 0
fi

[[ $# -eq 0 ]] || die "unknown argument: $1 (expected nothing, or --remove)"

# ---------------------------------------------------------------------
# 1. pacman's own keyring must exist before we can add anything to it
# ---------------------------------------------------------------------
if ! pacman-key -l >/dev/null 2>&1; then
  info "initialising pacman's keyring (pacman-key --init)"
  pacman-key --init
  pacman-key --populate archlinux
fi

# ---------------------------------------------------------------------
# 2. Fetch the public key and PROVE it is ours before trusting it
# ---------------------------------------------------------------------
tmpkey=$(mktemp) || die "could not create a temporary file"
trap 'rm -f "$tmpkey"' EXIT

info "fetching the signing key from $KEY_URL"
curl -fsSL --proto '=https' --tlsv1.2 -o "$tmpkey" "$KEY_URL" \
  || die "could not download $KEY_URL"

[[ -s "$tmpkey" ]] || die "downloaded key is empty"

# A file served at a URL is not evidence of anything by itself. Check
# what it actually contains before it goes anywhere near the keyring.
if gpg --show-keys --with-colons "$tmpkey" 2>/dev/null | grep -q '^sec'; then
  die "the downloaded file contains SECRET key material — refusing"
fi

got=$(gpg --show-keys --with-colons "$tmpkey" 2>/dev/null \
      | awk -F: '/^fpr/{print $10; exit}')
[[ -n "$got" ]] || die "the downloaded file is not a usable OpenPGP key"

if [[ "$got" != "$FPR" ]]; then
  die "FINGERPRINT MISMATCH
  expected: $FPR
  got:      $got
This means the key served at $KEY_URL is not the one this script
trusts. Do not proceed. Report it to packages@oniomarchy.com."
fi
info "key fingerprint verified: $FPR"

# ---------------------------------------------------------------------
# 3. Trust it
# ---------------------------------------------------------------------
info "importing the key into pacman's keyring"
pacman-key --add "$tmpkey"

# --add makes pacman aware of the key; --lsign-key is what makes it
# TRUSTED. Skipping the second step leaves a key that is known and
# useless, and the failure appears later as pacman rejecting the repo.
info "locally signing the key (this is what makes it trusted)"
pacman-key --lsign-key "$FPR"

# ---------------------------------------------------------------------
# 4. Add the repository
# ---------------------------------------------------------------------
if grep -q "^\[$REPO_NAME\]" "$PACMAN_CONF"; then
  info "[$REPO_NAME] is already in $PACMAN_CONF — leaving it alone"
else
  info "adding [$REPO_NAME] to $PACMAN_CONF"
  cp -a "$PACMAN_CONF" "$PACMAN_CONF.bak.$(date +%Y%m%d%H%M%S)"
  # Appended at the end, which puts it after [omarchy] and after the
  # official repos. Order decides who wins a name collision, and we must
  # never win one against core/extra/multilib or against [omarchy] —
  # publish.sh guard 3 enforces the first, and being last enforces the
  # rest structurally rather than by convention.
  cat >> "$PACMAN_CONF" <<EOF

[$REPO_NAME]
SigLevel = $SIGLEVEL
Server = $REPO_URL/\$arch
EOF
fi

# ---------------------------------------------------------------------
# 5. Sync, and install the keyring package so rotation reaches this machine
# ---------------------------------------------------------------------
info "synchronising package databases"
# Under DatabaseRequired this FAILS rather than degrading if the database
# signature does not verify. That is the intended behaviour.
pacman -Sy

info "installing oniomarchy-keyring"
# From here on the key is maintained by a package: a future rotation or
# revocation arrives as an ordinary upgrade instead of a support thread.
pacman -S --needed --noconfirm oniomarchy-keyring

cat <<EOF

$(info "[$REPO_NAME] is ready.")

  Server:    $REPO_URL/\$arch
  SigLevel:  $SIGLEVEL
  Key:       $FPR (expires 2029-09-04)
  Packages:  $(pacman -Sl "$REPO_NAME" 2>/dev/null | wc -l)

Every package from this repository is verified against that key before
it is installed. A package or database that fails verification is
refused, not warned about.

Problems with a package: packages@oniomarchy.com
To undo all of this:      sudo $0 --remove
EOF
