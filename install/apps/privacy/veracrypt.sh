# veracrypt — Privacy
# pack: core
#
# aarch64 has no `veracrypt` in any configured repository. Arch's own
# packaging/packages/veracrypt is arch=(x86_64) with `yasm` in
# makedepends — it builds VeraCrypt's x86 assembly crypto — so Arch Linux
# ARM, which rebuilds Arch's recipes as they stand, never produced one
# and pacman answers "error: target not found: veracrypt".
#
# That is a limitation of the packaging, not of VeraCrypt: upstream
# itself publishes an official arm64 build on Launchpad next to the amd64
# one. veracrypt-console-bin is exactly that artifact — a -bin package
# with a real source_aarch64 (veracrypt-<ver>-Debian-11-arm64.deb) and
# its own b2sum, not an x86_64 source repointed with --ignorearch. It is
# therefore the one option here that involves no compiling and no
# guessing: the binary comes from VeraCrypt's own release channel.
#
# Chosen over the two source-building alternatives deliberately:
#   - veracrypt-git is arch=(i686 x86_64) and carries two local patches
#     against upstream; it would need --ignorearch and would be an
#     unreviewed wx-3.2 build of a disk-encryption tool.
#   - veracrypt-inyourlanguage does declare aarch64 and does build the
#     GUI from the official Launchpad source tarball, so it is the right
#     answer if the GUI is wanted — swap the package name below. It is
#     not the default because it is a source build of security-critical
#     code by a third-party recipe, where the -bin package is the vendor's
#     own signed-off binary.
#
# The trade is the GUI: veracrypt-console-bin ships the `veracrypt` CLI
# only (no .desktop), and it tracks 1.26.14 against extra's 1.26.24. The
# CLI creates, mounts and dismounts volumes in full, veracrypt has no row
# in install/security/categories.tsv and no menu entry anywhere in this
# repo, so nothing in the toolkit depends on the GUI being there. It
# declares provides=('veracrypt') regardless, so anything that does ask
# pacman for `veracrypt` still resolves.
if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
  pkg_aur veracrypt-console-bin || {
    rc=$?
    # Already inside the ONIOMARCHY_AUR_FALLBACK branch; explicit
    # `exit "$rc"` rather than a trailing `[[ … ]] &&`, which under
    # `set -eE` would replace the status being preserved.
    cat >&2 <<'EOF'
oniomarchy: veracrypt-console-bin could not be installed from the AUR.
  There is no official aarch64 veracrypt: Arch's PKGBUILD is arch=(x86_64)
  and makedepends on yasm for the x86 assembly, so Arch Linux ARM never
  built one. veracrypt-console-bin repackages VeraCrypt's own arm64
  release .deb from Launchpad, so a failure here is almost always the
  download rather than a build — check the log above for a 404, which
  would mean the AUR package's pinned version (1.26.14) has been pruned
  from Launchpad and the package needs bumping upstream.
  If you want the GUI instead of the console build, veracrypt-inyourlanguage
  declares aarch64 and builds the official source tarball with wxWidgets;
  substituting it here is a one-word change.
EOF
    exit "$rc"
  }
else
  pkg_official veracrypt
fi
