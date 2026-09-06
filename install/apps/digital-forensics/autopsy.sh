# autopsy — Digital Forensics
#
# Unblocked 2026-09-01, simplified 2026-09-06 once [oniomarchy] began
# publishing this whole chain as signed binaries. autopsy, sleuthkit-java
# and java17-openjfx-bin are all published, so what used to be three
# careful builds is now three package installs.
#
# jdk17-openjdk is still installed by name, and that is not vestigial:
# autopsy and sleuthkit-java both depend on `java-runtime=17`, which
# several packages provide, and `omarchy pkg add` is `pacman -S
# --noconfirm` — which answers the "there are N providers" prompt with
# pacman's default rather than ours. It is also the exact JVM autopsy's
# own PKGBUILD hardcodes into autopsy.conf as
# jdkhome="/usr/lib/jvm/java-17-openjdk/".
#
# `ant` and `autoconf-archive` are gone from this line: both were
# makedepends for compiling sleuthkit-java here (autoconf-archive being a
# real undeclared gap — its AX_PKG_CHECK_MODULES macro, without which
# configure dies at line 22831). autoconf-archive is declared in the
# packaged PKGBUILD's makedepends now, and makedepends are not installed
# on the user's machine.
pkg_official jdk17-openjdk

# java17-openjfx-bin by name rather than letting the `java-openjfx=17`
# dependency resolve itself. Two AUR packages answer to it: java17-openjfx
# (built from source, flagged out-of-date, gcc13 plus a full WebKit/Qt
# toolchain — a multi-hour build) and java17-openjfx-bin (Gluon's prebuilt
# SDK, current, maintained by the same person who maintains autopsy and
# sleuthkit-java). Only the -bin one is published here, so the choice is
# already made, but naming it keeps the reason at the call site.
pkg_repo java17-openjfx-bin

# The JDK-17 class-version rebuild dance that used to sit here is gone.
#
# sleuthkit-java has to be COMPILED by JDK 17 and its PKGBUILD does not
# arrange that: makedepends=(ant java-environment=17) only guarantees a
# JDK 17 is installed, and ant then compiles with whatever `archlinux-java
# status` calls default. On a machine defaulting to something newer — this
# one defaults to java-26-openjdk — the jar came out at class file version
# 70 while autopsy's own conf pins jdkhome to java-17-openjdk, which reads
# 61 at most, and the GUI died on launch with UnsupportedClassVersionError.
# This leaf detected that by reading the class-file major out of the
# installed jar and forced a rebuild under JAVA_HOME=java-17-openjdk.
#
# It cannot recur: every [oniomarchy] package is built in a clean chroot
# where jdk17-openjdk is the only JDK that exists, so there is no wrong
# default to pick. Verified directly in the packaging repo by extracting
# sleuthkit-4.15.0.jar from the built package and reading class-file major
# 61 (= Java 17) with od. See its notes/build-status.md.
#
# Installed by name BEFORE autopsy, which is unchanged: autopsy depends on
# an exact sleuthkit-java version, and naming it keeps the ordering
# explicit rather than incidental.
pkg_repo sleuthkit-java

# Heads-up on size: autopsy's release zip is ~1.25 GB and package() copies
# the whole tree into /usr/share/autopsy. As a prebuilt binary this is now
# a download rather than a build, but it is still by a wide margin the
# largest thing in the install.
pkg_repo autopsy
