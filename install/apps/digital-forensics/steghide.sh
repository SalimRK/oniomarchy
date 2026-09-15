# steghide — Digital Forensics
# pack: core
#
# steghide 0.5.1 is from October 2003 and so is its autotools plumbing.
# The SourceForge tarball the AUR PKGBUILD downloads ships its own
# config.guess and config.sub, both stamped `timestamp='2002-11-30'` —
# eleven years older than aarch64, which neither file has ever heard of:
#
#     $ sh config.guess
#     ./config.guess: unable to guess system type
#     ...
#     UNAME_MACHINE = aarch64
#
# The PKGBUILD's build() ends in a bare `./configure --prefix=/usr
# --mandir=/usr/share/man`, so on this machine configure dies at its very
# first check — "configure: error: cannot guess build type; you must
# specify one" — and the build never reaches a compiler. That is the
# whole failure. Nothing in steghide's C++ is unportable: hand configure
# the triplet and it compiles clean, its unit tests pass, and a
# BMP embed/extract round-trips (verified on this host, 2026-09-11).
#
# The one-line fix belongs in the PKGBUILD (`./configure … --build=$CHOST`)
# and we do not own the PKGBUILD. What we can do without vendoring it is
# autoconf's own documented escape hatch: CONFIG_SITE names a shell
# script that every generated configure sources before it checks
# anything, and priming the ac_cv_build/host/target cache variables there
# makes configure skip config.guess entirely — "checking build system
# type... (cached) aarch64-unknown-linux-gnu". The variable survives the
# whole way down: this leaf is its own bash process (see run_app in
# install/apps/all.sh), so the export is scoped to this one package; yay
# execs makepkg with the environment it inherited; and makepkg 7.1.0 does
# not scrub the environment before running build().
#
# This is a nudge, not a lie. aarch64-unknown-linux-gnu is exactly what a
# current config.guess prints here and exactly what /etc/makepkg.conf's
# CHOST already says, so the answer we prime the cache with is the answer
# configure would have reached on its own if its copy were this decade's.
# If it were ever wrong the build would fail — which is where it stands
# today — so the guard below stays, and explains rather than guesses.
#
# Where the real fix lives: AUR steghide (maintainer marcs, active — last
# push 2026-09-08). A comment from `bluedevil` dated 2024-04-02 already
# asks for this exact flag and has never been picked up; the package also
# still declares arch=('x86_64') only, which is why the fallback needs
# --ignorearch (see pkg_aur in install/apps/lib/pkg.sh). steghide itself
# has had no upstream since 2003-10-15 and the live GitHub fork
# (StegHigh/steghide) carries the same 2002-11-30 config scripts.
if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
  # gcc's own triplet, which on Arch is CHOST by construction — read from
  # the compiler rather than by sourcing /etc/makepkg.conf, which under
  # `bash -eE` would drag that file's whole conditional body into this
  # shell for one variable. The last fallback is never reached on a host
  # that can build AUR packages at all.
  _steghide_triplet="$(gcc -dumpmachine 2>/dev/null || true)"
  [[ -n $_steghide_triplet ]] || _steghide_triplet="$(uname -m)-unknown-linux-gnu"

  _steghide_site="$(mktemp -t oniomarchy-steghide-config.site.XXXXXX)"
  trap 'rm -f "$_steghide_site"' EXIT
  cat >"$_steghide_site" <<EOF
# Written by oniomarchy for one build. steghide 0.5.1 ships a config.guess
# stamped 2002-11-30, which predates aarch64 and aborts configure; answer
# the question it cannot ask.
ac_cv_build=$_steghide_triplet
ac_cv_host=$_steghide_triplet
ac_cv_target=$_steghide_triplet
EOF
  export CONFIG_SITE="$_steghide_site"
fi

pkg_repo steghide || {
  rc=$?
  if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
    cat >&2 <<'EOF'
oniomarchy: steghide could not be built from the AUR on aarch64.
  steghide 0.5.1 (2003) ships config.guess and config.sub stamped
  timestamp='2002-11-30', which predate aarch64, so the PKGBUILD's bare
  `./configure --prefix=/usr --mandir=/usr/share/man` aborts with
  "configure: error: cannot guess build type; you must specify one"
  before a single source file is compiled. The code itself is fine on
  aarch64 — given the triplet it builds and its unit tests pass.
  This leaf primes CONFIG_SITE with ac_cv_build/host/target so configure
  skips config.guess; reaching this message means that did not take —
  check the log for "checking build system type", and whether the
  PKGBUILD or makepkg dropped CONFIG_SITE from the build environment.
  The proper fix is one line in the AUR PKGBUILD:
      ./configure --prefix=/usr --mandir=/usr/share/man --build="$CHOST"
  plus 'aarch64' in arch=(). Ask AUR/steghide's maintainer (marcs) —
  bluedevil's 2024-04-02 comment there already requests exactly this.
EOF
  fi
  exit "$rc"
}
