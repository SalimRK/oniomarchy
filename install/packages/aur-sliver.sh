# sliver vendors a gvisor snapshot gated `//go:build go1.13 && !go1.21`,
# incompatible with any Go newer than 1.20 (this system has 1.27+). Go's
# built-in toolchain switching (since 1.21) auto-downloads and uses the
# pinned version for just this build when GOTOOLCHAIN is set — no
# PKGBUILD edit needed. See notes/install-issues.md fix #8.
source "$ONIOMARCHY_INSTALL/packages/lib-clean-build-path.sh"

export GOTOOLCHAIN=go1.20.14
omarchy pkg aur add sliver
