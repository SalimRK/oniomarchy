# autopsy — Digital Forensics
#
# Unblocked 2026-09-01. This was in notes/pentest-tools.md's Gaps as
# "currently broken" because autopsy and its sleuthkit-java dependency
# both pin `java-openjfx=17` exactly, and the only AUR package answering
# to that name had moved on to 28.x. That is no longer true: two AUR
# packages now declare `provides=('java-openjfx=17')`, so the pin
# resolves and nothing has to be patched here.
#
# Which of the two matters, though, and the choice is not left to yay:
#
#   java17-openjfx      17.0.18.u1  built from source, flagged
#                                   out-of-date, and its makedepends
#                                   include gcc13 plus a full WebKit/Qt
#                                   toolchain — a multi-hour build.
#   java17-openjfx-bin  17.0.19     Gluon's prebuilt SDK, current, and
#                                   maintained by the same person who
#                                   maintains autopsy and sleuthkit-java.
#
# `omarchy pkg aur add` is `yay -S --noconfirm --needed`, and --noconfirm
# takes yay's default answer to the "there are 2 providers" prompt rather
# than ours. So the -bin package is installed by name first, the same way
# armitage.sh installs its own JDK: an ambiguous or undeclared dependency
# lives with the app that needs it.
#
# jdk17-openjdk (official) is installed by name for the same reason — it
# satisfies both `java-runtime=17` (autopsy, sleuthkit-java) and
# `java-environment=17` (java17-openjfx-bin, and sleuthkit-java's ant
# build), each of which otherwise has several possible providers. It is
# also the exact JVM autopsy's own PKGBUILD hardcodes into autopsy.conf
# as `jdkhome="/usr/lib/jvm/java-17-openjdk/"`.
#
# ant is sleuthkit-java's build tool; sleuthkit and testdisk are autopsy's
# runtime dependencies and already have their own leaves in this category,
# so they are not repeated here — --needed makes leaf order irrelevant.
#
# autoconf-archive is a real makedepends gap in the sleuthkit-java
# PKGBUILD, not a preference. Its build() runs `autoreconf -fi`, which
# regenerates configure from scratch, and sleuthkit's own m4/ ships
# every macro that regeneration needs except AX_PKG_CHECK_MODULES —
# called from m4/tsk_opt_dep_check.m4 and owned by autoconf-archive
# (extra). Without it the macro is never expanded, so it survives into
# the generated script as a literal shell word and configure dies at
# line 22831 with `syntax error near unexpected token 'SQLITE3,'` after
# several minutes of checks. The PKGBUILD does not declare it, so yay
# will not pull it in; installing it here is what makes the build
# reproducible on a machine that has never built an autotools project.
#
# Heads-up on size: autopsy's release zip is ~1.25 GB and package() copies
# the whole tree into /usr/share/autopsy, so this is by a wide margin the
# longest-running leaf in the install. sleuthkit-java compiles the C
# library plus two ant builds on top of that.
pkg_official jdk17-openjdk ant autoconf-archive

pkg_aur java17-openjfx-bin

# sleuthkit-java has to be COMPILED by JDK 17, and its PKGBUILD does not
# arrange that. `makedepends=(ant java-environment=17)` only guarantees a
# JDK 17 is installed; ant then compiles with whatever
# `archlinux-java status` calls default. On a machine whose default is
# newer — this one defaults to java-26-openjdk — the jar comes out at
# class file version 70 while autopsy's own autopsy.conf hardcodes
# `jdkhome="/usr/lib/jvm/java-17-openjdk/"`, which reads 61 at most. The
# install succeeds and the GUI then dies on launch:
#
#   java.lang.UnsupportedClassVersionError: org/sleuthkit/datamodel/
#   TskCoreException has been compiled by a more recent version of the
#   Java Runtime (class file version 70.0), this version of the Java
#   Runtime only recognizes class file versions up to 61.0
#
# autopsy symlinks modules/ext/sleuthkit-<ver>.jar to the one in
# /usr/share/java, so there is exactly one jar to get right and no
# separate copy inside autopsy's own tree.
#
# JAVA_HOME is exported rather than `archlinux-java set` — the selection
# is scoped to this build instead of changing what every other Java app
# on the system uses. ant honours JAVA_HOME, and so does the configure
# step's AX_JNI_INCLUDE_DIR when it goes looking for the JNI headers.
_autopsy_jdk17=/usr/lib/jvm/java-17-openjdk

# Class file major 61 is Java 17 (the mapping is major - 44). Anything
# higher means the jar was built by a newer JDK than autopsy will run.
_autopsy_tsk_class_major() {
  bsdtar -xOf "$1" org/sleuthkit/datamodel/TskCoreException.class 2>/dev/null |
    od -An -tu1 -j6 -N2 | awk '{print $1 * 256 + $2}'
}

# sleuthkit-java is installed by name BEFORE autopsy. Left to itself,
# `pkg_aur autopsy` would pull it in as a dependency and build it under
# the default JDK again, which is the whole bug.
_autopsy_tsk_rebuild_reason=""
if pacman -Qq sleuthkit-java &>/dev/null; then
  _autopsy_tsk_jar=$(pacman -Ql sleuthkit-java | awk '{print $2}' |
    grep -E '/usr/share/java/sleuthkit-[0-9.]+\.jar$' | head -1)
  _autopsy_tsk_major=$(_autopsy_tsk_class_major "$_autopsy_tsk_jar")
  if [[ -z $_autopsy_tsk_major ]]; then
    _autopsy_tsk_rebuild_reason="cannot read class version from $_autopsy_tsk_jar"
  elif ((_autopsy_tsk_major > 61)); then
    _autopsy_tsk_rebuild_reason="jar is class $_autopsy_tsk_major (JDK $((_autopsy_tsk_major - 44))), autopsy runs JDK 17"
  fi
fi

if [[ -n $_autopsy_tsk_rebuild_reason ]]; then
  # --needed would skip an already-installed-but-wrong build, the same
  # situation wfuzz.sh handles the same way.
  echo "==> Rebuilding sleuthkit-java under JDK 17 ($_autopsy_tsk_rebuild_reason)"
  JAVA_HOME="$_autopsy_jdk17" PATH="$_autopsy_jdk17/bin:$PATH" \
    retry_transfer yay -S --rebuild --noconfirm sleuthkit-java
else
  JAVA_HOME="$_autopsy_jdk17" PATH="$_autopsy_jdk17/bin:$PATH" \
    pkg_aur sleuthkit-java
fi

unset _autopsy_jdk17 _autopsy_tsk_jar _autopsy_tsk_major _autopsy_tsk_rebuild_reason
unset -f _autopsy_tsk_class_major

pkg_aur autopsy
