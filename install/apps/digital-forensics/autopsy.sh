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
# Heads-up on size: autopsy's release zip is ~1.25 GB and package() copies
# the whole tree into /usr/share/autopsy, so this is by a wide margin the
# longest-running leaf in the install. sleuthkit-java compiles the C
# library plus two ant builds on top of that.
pkg_official jdk17-openjdk ant

pkg_aur java17-openjfx-bin
pkg_aur autopsy
