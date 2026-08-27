# wfuzz has three independent, already-diagnosed problems, all fixed here
# rather than by the generic aur.sh batch:
#
# 1. It was originally installed (2026-08-25) before
#    lib-clean-build-path.sh existed, so its entry-point scripts'
#    shebang got baked to mise's Python
#    (~/.local/share/mise/installs/python/.../bin/python) instead of the
#    system one. Sourcing lib-clean-build-path.sh + forcing a rebuild
#    fixes that going forward — `yay -S --needed` alone would just skip
#    an already-installed package and leave the bad shebang in place, so
#    this always passes --rebuild.
#
# 2. Real upstream/environment incompatibility, independent of mise:
#    wfuzz/helpers/file_func.py does a module-level `import pkg_resources`
#    used nowhere except get_filter_help_file()'s
#    pkg_resources.resource_filename() call, but current
#    python-setuptools (84.0.0) has dropped the pkg_resources module
#    entirely — so the import fails before wfuzz even starts, on every
#    single invocation, mise or no mise. wfuzz (last real upstream
#    release 2020) predates that removal. No compat package exists
#    (checked both official repos and AUR). Since the import's only use
#    is fetching a bundled help text file, this patches it to the modern
#    stdlib replacement (importlib.resources) rather than pinning
#    setuptools system-wide, which would risk breaking every other AUR
#    build that needs a current setuptools.
#
#    Patching the cached PKGBUILD's prepare() step (the pattern
#    aur-patches.sh uses for python-aiomultiprocess) does NOT work here —
#    confirmed live: `yay -S` resyncs ~/.cache/yay/wfuzz against its AUR
#    git remote as part of every build, silently discarding the local
#    PKGBUILD edit before prepare() ever runs, even with no new upstream
#    commit to justify a reset. So this patches the installed file
#    directly instead, right after each rebuild — the real installed
#    path is looked up via `pacman -Ql` rather than a hardcoded
#    site-packages/python3.NN path, the same verify-don't-guess rule
#    verify-binaries.sh follows for binary names. Idempotent: skipped if
#    the patch marker is already present. See notes/install-issues.md.
#
# 3. wxfuzz (wfuzz's GUI entry point) fails separately even with fix #2
#    applied: wfuzz/ui/gui/controller.py has three broken relative
#    imports — genuine upstream bugs, confirmed by reading the real
#    installed package tree, not guessed:
#      - `from .ui.console.clparser import CLParser` — controller.py's
#        own package is wfuzz.ui.gui, but clparser.py actually lives at
#        wfuzz/ui/console/clparser.py, one level up then across, so this
#        needs `..console.clparser`, not `.ui.console.clparser`.
#      - `from .ui.gui.model import GUIModel` — model.py is a sibling of
#        controller.py (wfuzz/ui/gui/model.py), so this just needs
#        `.model`.
#      - `from .facade import Facade` — facade.py lives at the top-level
#        wfuzz/facade.py, two packages up from wfuzz.ui.gui, so this
#        needs `...facade`.
#    Looks like this GUI code path has never actually run against
#    Python 3's relative-import semantics. Patched the same way as fix
#    #2 (installed file, path via `pacman -Ql`, cached-PKGBUILD patching
#    doesn't survive rebuilds here either).
source "$ONIOMARCHY_INSTALL/packages/lib-clean-build-path.sh"

yay -S --rebuild --noconfirm wfuzz

_file_func=$(pacman -Ql wfuzz | awk '/wfuzz\/helpers\/file_func\.py$/ {print $2}')
if [[ -z $_file_func ]]; then
  echo "oniomarchy: wfuzz's helpers/file_func.py not found via pacman -Ql — package layout may have changed, pkg_resources patch skipped" >&2
elif grep -q '_oniomarchy_ilr_files' "$_file_func"; then
  echo "==> wfuzz's pkg_resources patch already applied"
else
  # site-packages is root-owned; the yay -S above already took a sudo
  # prompt in this same terminal, so this reuses it rather than being a
  # surprise second one.
  sudo sed -i \
    -e 's/^import pkg_resources$/from importlib.resources import files as _oniomarchy_ilr_files/' \
    -e 's/pkg_resources\.resource_filename("wfuzz", FILTER_HELP_FILE)/str(_oniomarchy_ilr_files("wfuzz") \/ FILTER_HELP_FILE)/' \
    "$_file_func"
  echo "==> Patched $_file_func to use importlib.resources instead of pkg_resources"
fi
unset _file_func

_controller=$(pacman -Ql wfuzz | awk '/wfuzz\/ui\/gui\/controller\.py$/ {print $2}')
if [[ -z $_controller ]]; then
  echo "oniomarchy: wfuzz's ui/gui/controller.py not found via pacman -Ql — package layout may have changed, wxfuzz relative-import patch skipped" >&2
elif ! grep -q '^from \.ui\.console\.clparser import CLParser$' "$_controller"; then
  echo "==> wxfuzz's relative-import patch already applied"
else
  sudo sed -i \
    -e 's/^from \.ui\.console\.clparser import CLParser$/from ..console.clparser import CLParser/' \
    -e 's/^from \.ui\.gui\.model import GUIModel$/from .model import GUIModel/' \
    -e 's/^from \.facade import Facade$/from ...facade import Facade/' \
    "$_controller"
  echo "==> Patched $_controller's three broken relative imports (wxfuzz GUI mode)"
fi
unset _controller
