# theharvester-git's PKGBUILD builds with `python -m build -wn` (no
# isolation), which imports flit_core from whatever's already on
# sys.path — but the package's own pyproject.toml caps it at
# `flit_core >=3.11,<4`, while the system's python-flit-core
# (pacman-owned) is 4.0.2. Patching the PKGBUILD doesn't stick here the
# way it does for python-aiomultiprocess (see aur-patches.sh): this is a
# `-git`/VCS package, and makepkg's pkgver() version-bump step resets
# the cached PKGBUILD from upstream on every single build (confirmed —
# a sed patch survived exactly one run before silently reverting, see
# notes/install-issues.md fix #3 history). Instead: install a pinned,
# isolated copy of a compatible flit_core into its own directory (never
# touching the pacman-owned system one) and point PYTHONPATH at it for
# just this build, so the `-wn` build's import resolves to it ahead of
# the system's too-new version. Verified directly against theharvester's
# actual build() invocation before scripting this.
source "$ONIOMARCHY_INSTALL/packages/lib-clean-build-path.sh"

_flit_override="$HOME/.cache/oniomarchy/pip-overrides/flit_core"
if [[ ! -d "$_flit_override" ]]; then
  python -m pip install --quiet --target "$_flit_override" "flit_core>=3.11,<4"
fi
PYTHONPATH="$_flit_override${PYTHONPATH:+:$PYTHONPATH}" omarchy pkg aur add theharvester-git
unset _flit_override
