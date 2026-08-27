# armitage-git bundles a Gradle wrapper pinned to 6.8, which cannot run
# on JDK 17+ (installed as the default java-environment). jdk11-openjdk
# (install/packages/official.packages) provides a compatible JDK; Gradle
# reads JAVA_HOME from the environment, so exporting it here is enough —
# no PKGBUILD edit needed. See notes/install-issues.md fix #7.
source "$ONIOMARCHY_INSTALL/packages/lib-clean-build-path.sh"

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
omarchy pkg aur add armitage-git
