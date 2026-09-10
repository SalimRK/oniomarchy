# ghidra — Reverse Engineering
# pack: core
#
# aarch64 has no `ghidra` in any configured repository, and the reason is
# in Arch's own recipe rather than in Ghidra. packaging/packages/ghidra's
# PKGBUILD is arch=(x86_64) because it hardcodes the platform three
# times: it stages libz3 into dependencies/SymbolicSummaryZ3/os/
# linux_x86_64, builds the natives with `gradle buildNatives_linux_x86_64`,
# and unpacks ghidra_*_linux_x86_64.zip. Arch Linux ARM rebuilds Arch's
# recipes as they stand and simply never builds what Arch does not
# declare buildable for the arch — so core/extra/alarm have no ghidra at
# all and pacman answers "error: target not found: ghidra", which names
# the symptom and none of the cause. Hence this branch.
#
# ghidra-git is the same software with none of that hardcoding:
# arch=('x86_64' 'aarch64'), a platform-agnostic `gradle buildGhidra`,
# and it unpacks whatever zip that produced — so the decompiler and
# demangler natives get built for the host. Ghidra itself has shipped
# linux_arm_64 support since 10.3; only Arch's packaging was x86_64-only.
#
# Two things about the build, both real and neither fixable from here:
#
# 1/ It is the longest single item in an aarch64 run — prepare() pulls
#    the whole third-party set via gradle/support/fetchDependencies.gradle
#    before build() compiles the tree. That is the price of there being
#    no prebuilt aarch64 Ghidra anywhere to install instead.
# 2/ Its prepare() runs `java --version` and aborts unless the SYSTEM
#    DEFAULT java is 25 or newer — present is not enough. yay installs
#    jdk-openjdk to satisfy java-environment>=25, and on a machine with
#    no other JDK the package hook makes it the default, so a plain core
#    run is fine. A run that also selected digital-forensics installs
#    jdk17-openjdk first (apps/digital-forensics/autopsy.sh names it
#    deliberately) and the first JDK installed keeps the default — which
#    is why the message below points at archlinux-java rather than at us.
#
# ghidra-git declares provides=('ghidra'), and both `pacman -Qi` and
# `pacman -Ql` resolve provides, so install/security/verify-binaries.sh
# still matches the `ghidra` row in categories.tsv and the Security menu
# comes out identical to x86_64's.
if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
  echo "==> ghidra-git: full source build (gradle) — expect this step to take a while"
  pkg_aur ghidra-git || {
    rc=$?
    # Already inside the ONIOMARCHY_AUR_FALLBACK branch, so no second
    # test is needed to gate the explanation — and an explicit `exit`
    # rather than a trailing `[[ … ]] &&`, which under `set -eE` would
    # replace the status we are trying to preserve.
    cat >&2 <<'EOF'
oniomarchy: ghidra-git could not be built from the AUR.
  Ghidra is x86_64-only in Arch (its PKGBUILD hardcodes
  buildNatives_linux_x86_64 and linux_x86_64.zip), so Arch Linux ARM
  never built it and there is no official package to fall back to.
  Check the log above for which of the two usual causes it was:
  - "You seem to have jdk25 or above installed correctly but your system
    defaults to another java version" — ghidra-git's prepare() requires
    the SYSTEM DEFAULT java to be 25+, not merely installed. Fix with
    `sudo archlinux-java set java-26-openjdk` (or java-25-openjdk) and
    re-run; a run that also installed jdk17-openjdk for autopsy is the
    usual way this happens.
  - a gradle fetch/compile failure — that is upstream ghidra-git, whose
    aarch64 support its maintainer flags as untested in the PKGBUILD
    itself ("Not sure aarch64 is correct here").
  Nothing here needs changing either way: the moment ghidra-git builds,
  this leaf works, because it is the only aarch64 Ghidra that exists.
EOF
    exit "$rc"
  }
else
  pkg_official ghidra
fi
