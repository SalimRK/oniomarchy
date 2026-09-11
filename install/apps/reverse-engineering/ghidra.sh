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
# 2/ Its prepare() runs `java --version` and greps for 25+ — present is
#    not enough, it reads whatever `java` resolves to on PATH. That is
#    normally the archlinux-java default, so a run that also selected
#    digital-forensics (autopsy.sh installs jdk17-openjdk, and the first
#    JDK installed keeps the default) leaves `java` at 17 and the build
#    aborts. We do NOT flip the global default — jdk17-only tools need it
#    — we install a >=25 JDK and put it first on PATH for this one build,
#    which is all `java --version` looks at. Installing jdk-openjdk
#    ourselves via pkg_official (rather than leaving it to yay's makedep
#    resolution) also gets the transfer-retry policy, since the ALARM
#    mirror stalls on the ~140 MiB jdk download.
#
# ghidra-git declares provides=('ghidra'), and both `pacman -Qi` and
# `pacman -Ql` resolve provides, so install/security/verify-binaries.sh
# still matches the `ghidra` row in categories.tsv and the Security menu
# comes out identical to x86_64's.
if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
  # A >=25 JDK on PATH for prepare()'s `java --version`, without touching
  # the system default. sort -V picks the newest if several are present.
  pkg_official jdk-openjdk
  _ghidra_jdk="$(ls -d /usr/lib/jvm/java-2[5-9]-openjdk /usr/lib/jvm/java-[3-9][0-9]-openjdk 2>/dev/null | sort -V | tail -1)"
  [[ -n $_ghidra_jdk ]] && export PATH="$_ghidra_jdk/bin:$PATH"
  unset _ghidra_jdk

  # Ghidra's PKGBUILD runs `gradle --parallel buildGhidra`, and a parallel
  # compile of a tree this size is the heaviest memory moment in the whole
  # toolkit — enough to trip the OOM killer on a small box (seen on a 3.8 GB
  # aarch64 VM: the build reached :VersionTracking:compileJava, then the
  # process tree was SIGKILLed with no abort banner). We cannot drop the
  # PKGBUILD's `--parallel`, but gradle still honours these: no daemon (so
  # its heap is freed at once, not held), a single worker (caps concurrent
  # compiler forks despite --parallel), and a bounded build-JVM heap. This
  # trades build time for a much lower peak so a constrained host can finish;
  # it does not raise the ceiling on a host that simply lacks the RAM+swap.
  export GRADLE_OPTS="${GRADLE_OPTS:+$GRADLE_OPTS }-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1 -Dorg.gradle.jvmargs=-Xmx2g"

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
  - the build tree stops mid-compile with no error of its own — that is
    the OOM killer. Ghidra's `gradle --parallel buildGhidra` is the
    heaviest step in the toolkit; this leaf already caps gradle (no daemon,
    one worker, -Xmx2g) to survive a small box, but Ghidra from source
    still wants roughly 4 GB of RAM+swap. Add swap (or build it on a
    roomier host and copy the package in) and re-run.
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
