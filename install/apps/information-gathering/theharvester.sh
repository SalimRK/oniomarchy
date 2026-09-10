# theharvester — Information Gathering
# pack: core
#
# This leaf used to carry three fixes, all of them build-time and all of
# them now handled inside the package [oniomarchy] publishes:
#
# 1/ Its AUR PKGBUILD's depends=() was missing two real runtime imports,
#    python-aiohttp-socks and python-sqlalchemy, without which theHarvester
#    crashes with ModuleNotFoundError the moment it runs. Our PKGBUILD
#    declares both (and python-dateutil, a third gap found the same way),
#    so pacman pulls them in.
# 2/ Its build dependency python-aiomultiprocess built with `python -m
#    build -wn` against a flit_core its own pyproject.toml caps out. It is
#    published here as its own package, built correctly.
# 3/ theharvester-git itself hit the same flit_core cap, worked around on
#    the user's machine by pip-installing a pinned flit_core into a
#    private directory. Our PKGBUILD drops `-n` instead, so pip fetches
#    the right flit_core into a throwaway build venv at build time.
#
# See notes/install-issues.md fixes #3/#4/#5 for the original diagnoses,
# and the packaging repo's notes/build-status.md for how each was fixed.
#
# None of that reaches aarch64, where there is no [oniomarchy] tree and
# pkg_repo builds theharvester-git straight from the AUR (fix #2 is
# exactly what fails there — see the message below). The attempt is still
# made rather than pre-emptively skipped: the blocker is one stale AUR
# package, and the day it is bumped this leaf starts working again with
# no change here. What the guard adds is an explanation, so the operator
# gets the cause instead of a flit_core traceback in the log.
pkg_repo theharvester-git || {
  rc=$?
  if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
    cat >&2 <<'EOF'
oniomarchy: theharvester-git cannot be built from the AUR right now.
  Its dependency python-aiomultiprocess is pinned to upstream 0.9.0, whose
  pyproject.toml still declares [tool.flit.metadata] — a table flit_core
  >= 4 refuses to read (extra/python-flit-core is 4.0.2), and its PKGBUILD
  builds with `python -m build -wn`, so there is no isolated build env for
  pip to fetch the flit_core < 4 that pyproject asks for. It has been
  flagged out-of-date in the AUR since 2025-03-03.
  Nothing else in the tree fails: python-slowapi and python-limits build,
  and every other dependency is an official package.
  The fix is upstream, not here: python-aiomultiprocess needs bumping to
  0.9.1, which moved to the standard [project] table. (theHarvester itself
  dropped aiomultiprocess a while ago — the AUR depends=() is stale twice
  over — but pacman still has to satisfy what the PKGBUILD declares.)
EOF
  fi
  exit "$rc"
}
