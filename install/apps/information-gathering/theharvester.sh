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
pkg_repo theharvester-git
