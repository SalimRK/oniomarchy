# theharvester-git pulls in python-aiomultiprocess as a build dependency.
# That package's PKGBUILD builds with `python -m build -wn` (no
# isolation), which uses whatever flit_core is already on the *system*
# (python-flit-core, currently 4.0.2) — but its own pyproject.toml caps
# it at `flit_core >=2,<4`. Real upstream AUR bug, not machine-specific.
# python-aiomultiprocess is a regular (non-VCS) AUR package, so a local
# uncommitted PKGBUILD edit survives yay's update check when there's no
# new upstream commit to pull — confirmed across multiple reruns this
# session. (theharvester-git itself needed a different fix — it's a
# `-git`/VCS package whose pkgver() step resets the cached PKGBUILD from
# upstream on every build, wiping this kind of edit; see
# install/packages/aur-theharvester.sh instead.) Pre-clone into yay's
# own cache location and patch build() to `-w` (isolated) so pip fetches
# a compatible flit_core into a throwaway venv instead of touching the
# system package. Idempotent; safe on a fresh clone since this does its
# own cloning if the cache doesn't exist yet. See
# notes/install-issues.md fix #5.
source "$ONIOMARCHY_INSTALL/packages/lib-clean-build-path.sh"

_pkg_dir="$HOME/.cache/yay/python-aiomultiprocess"
if [[ ! -d "$_pkg_dir" ]]; then
  git clone --quiet https://aur.archlinux.org/python-aiomultiprocess.git "$_pkg_dir"
fi
sed -i 's/python -m build -wn/python -m build -w/' "$_pkg_dir/PKGBUILD"
unset _pkg_dir
