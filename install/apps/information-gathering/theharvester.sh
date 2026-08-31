# theharvester — Information Gathering
#
# Three separate fixes, all of them theHarvester's alone — which is why
# they now live here instead of in a shared aur-patches.sh:
#
# 1/ Its PKGBUILD's depends=() is missing two real runtime imports,
#    python-aiohttp-socks and python-sqlalchemy (both in extra). Without
#    them theHarvester crashes with ModuleNotFoundError the moment it runs.
# 2/ Its build dependency python-aiomultiprocess builds with
#    `python -m build -wn` (no isolation) against the system flit_core
#    4.0.2, while its own pyproject.toml caps it at <4. Real upstream AUR
#    bug. python-aiomultiprocess is a regular (non-VCS) package, so a
#    local PKGBUILD edit survives yay's update check — patch build() to
#    `-w` (isolated) so pip fetches a compatible flit_core into a
#    throwaway venv instead of touching the system package.
# 3/ theharvester-git itself hits the same flit_core cap, but the patch
#    trick above does NOT work on it: it is a -git/VCS package, and
#    makepkg's pkgver() step resets the cached PKGBUILD from upstream on
#    every build (a sed patch survived exactly one run before silently
#    reverting). Instead, install a pinned, isolated flit_core into its
#    own directory — never touching the pacman-owned system one — and
#    point PYTHONPATH at it for just this build.
#
# See notes/install-issues.md fixes #3/#4/#5.
pkg_official python-aiohttp-socks python-sqlalchemy

_aiomultiprocess="$HOME/.cache/yay/python-aiomultiprocess"
if [[ ! -d "$_aiomultiprocess" ]]; then
  git clone --quiet https://aur.archlinux.org/python-aiomultiprocess.git "$_aiomultiprocess"
fi
sed -i 's/python -m build -wn/python -m build -w/' "$_aiomultiprocess/PKGBUILD"
unset _aiomultiprocess

_flit_override="$HOME/.cache/oniomarchy/pip-overrides/flit_core"
if [[ ! -d "$_flit_override" ]]; then
  python -m pip install --quiet --target "$_flit_override" "flit_core>=3.11,<4"
fi
PYTHONPATH="$_flit_override${PYTHONPATH:+:$PYTHONPATH}" pkg_aur theharvester-git
unset _flit_override
