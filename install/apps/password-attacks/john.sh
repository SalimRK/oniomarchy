# john — Password Attacks
# pack: core
#
# aarch64 has no `john` in any configured repository. Arch's own
# packaging/packages/john is arch=('x86_64') and, unlike metasploit's,
# that tag is not merely conservative: its build() compiles John three
# times under `if [[ "${CARCH}" == "x86_64" ]]` — a baseline pass, then
# -mavx, then -mxop — and installs them as john-non-avx/john-non-xop
# beside `john` so the runtime can pick the best one for the CPU. That
# recipe has nothing to say about any other 64-bit arch, so Arch Linux
# ARM (which rebuilds Arch's recipes as they stand) never produced a
# package and pacman answers "error: target not found: john".
#
# john-git is the same jumbo tree with the missing branch filled in:
# arch=('i686' 'x86_64' 'aarch64') and an explicit `elif [[ "${CARCH}" ==
# "aarch64" ]]` that configures and builds once, with the same
# --enable-openmp/--enable-mpi/--enable-opencl/--enable-pcap options as
# x86_64 gets. So this is not a downgrade to a stripped build — it is the
# one SIMD-variant trick that does not apply off x86, and John's own
# NEON/ASIMD formats are selected by configure exactly as usual.
#
# Every dependency it names is already in core/extra on this machine.
# opencl-icd-loader is worth a note because it looks missing and is not:
# there is no package by that name on aarch64, extra/ocl-icd provides it,
# and pacman resolves provides — so `yay` satisfies it without comment.
#
# john-git declares provides=('john'), and `pacman -Qi`/`pacman -Ql` both
# resolve provides, so install/security/verify-binaries.sh still matches
# the `john<TAB>password<TAB>collapse<TAB>john` row in categories.tsv and
# the Password Attacks menu is identical to x86_64's.
if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
  pkg_aur john-git || {
    rc=$?
    # Already inside the ONIOMARCHY_AUR_FALLBACK branch, so the
    # explanation is gated by construction. Explicit `exit "$rc"` rather
    # than a trailing `[[ … ]] &&`, which under `set -eE` would overwrite
    # the very status this is preserving.
    cat >&2 <<'EOF'
oniomarchy: john-git could not be built from the AUR.
  There is no official aarch64 John the Ripper to fall back to: Arch's
  own PKGBUILD is arch=('x86_64') because it builds three x86 SIMD
  variants (baseline/-mavx/-mxop), so Arch Linux ARM never built one.
  john-git is the only aarch64-capable recipe in the AUR and it does
  declare aarch64 with a real build branch for it, so a failure here is
  a build problem to read out of the log above — not a missing package
  and not something this leaf can substitute around.
EOF
    exit "$rc"
  }
else
  pkg_official john
fi
