# recon-ng — Information Gathering
#
# Unblocked 2026-09-01. The AUR package was never the problem: recon-ng
# 5.1.2-2 is maintained and matches upstream's newest tag. Exactly one of
# its 13 dependencies, python-flasgger, exists in neither the official
# repos nor the AUR — pip-only — and `yay` cannot resolve a pip-only
# package, so the whole install failed on that one missing ingredient.
#
# The fix is to supply the missing dependency rather than work around it.
# Dropping it instead would have been wrong in a quiet way: flasgger is
# imported by exactly one file, recon/core/web/__init__.py, so it gates
# only `recon-web` (the Swagger/REST UI). `recon-ng` and `recon-cli` both
# enter through recon.core.base, which never imports flask or flasgger.
# A PKGBUILD copy with the `# web` deps stripped would work for two of
# the three entry points and silently ImportError on the third.
#
# WHY THIS BUILDS A PACKAGE LOCALLY — the one place in this repo that
# does. The intent was to publish python-flasgger to the AUR, which
# would reduce this whole leaf to a single `pkg_aur recon-ng` line and
# fix it for everyone else too (the same publish-upstream shape as
# macarchy). AUR account registration was closed at the time
# ("temporarily paused while we deal with a wave of automated account
# creation"), so the recipe lives here instead.
#
# That is meant to be temporary, and collapsing it back is deliberately
# easy: files/python-flasgger/PKGBUILD is the source of truth and is
# already AUR-shaped. Publishing it is `makepkg --printsrcinfo >
# .SRCINFO` plus a push, after which everything between the two markers
# below deletes and only `pkg_aur recon-ng` remains. A staging clone with
# the AUR remote already set sits at ~/Projects/python-flasgger.
#
# Verified before any of this was wired up: the package builds clean
# under a mise-free PATH, and the built result imports against Arch's
# *current* Flask 3.1 and mistune 3.3.4 — `from mistune import markdown`,
# the call flasgger's base.py makes, still exists in mistune 3.x, so no
# patch is needed — with both /apispec_1.json and /apidocs/ returning 200
# in a live Flask test client.

# --- BEGIN local python-flasgger build (delete once it is on the AUR) ---
#
# flasgger's own dependencies, plus the four makedepends its PKGBUILD
# needs. Installed here rather than letting `makepkg -s` do it, so that
# makepkg never has to invoke sudo on its own — this leaf takes exactly
# one privileged action, the pacman -U at the end, and install.sh has
# already primed sudo by the time apps run.
pkg_official python-flask python-jsonschema python-mistune python-packaging \
             python-six python-yaml \
             python-build python-installer python-setuptools python-wheel

_flasgger_src="$ONIOMARCHY_APP_DIR/files/python-flasgger"

# The wanted version is read out of the PKGBUILD rather than repeated
# here, so bumping flasgger is a one-file edit and this check cannot
# drift out of sync with what it is checking for.
_flasgger_want="$(awk -F= '
  /^pkgver=/ { v = $2 }
  /^pkgrel=/ { r = $2 }
  END        { print v "-" r }
' "$_flasgger_src/PKGBUILD")"
_flasgger_have="$(pacman -Q python-flasgger 2>/dev/null | awk '{print $2}')"

if [[ -n $_flasgger_have && $_flasgger_have == "$_flasgger_want" ]]; then
  echo "==> python-flasgger $_flasgger_want already installed — skipping local build"
else
  # Built outside the repo: makepkg litters src/ and pkg/ and drops a
  # package artifact beside the PKGBUILD, none of which belongs in a
  # tracked tree. Same ~/.cache/oniomarchy home theharvester.sh uses for
  # its build-scoped override.
  _flasgger_build="$HOME/.cache/oniomarchy/python-flasgger"
  mkdir -p "$_flasgger_build"
  cp "$_flasgger_src/PKGBUILD" "$_flasgger_build/PKGBUILD"

  # Same reason every AUR build in this repo needs it: mise shims python
  # ahead of the system one on this machine, and `python -m installer`
  # under mise writes outside the fakeroot sandbox. pkg_aur does this
  # itself, but makepkg here runs before the first pkg_aur call.
  source "$ONIOMARCHY_INSTALL/apps/lib/clean-build-path.sh"

  echo "==> Building python-flasgger $_flasgger_want (no AUR package exists — see comment above)"
  ( cd "$_flasgger_build" && makepkg -f --noconfirm )

  # Ask makepkg for the artifact's real path instead of globbing for it —
  # PKGEXT is configurable, so the .pkg.tar.zst suffix is a local default,
  # not a guarantee. Same verify-don't-guess rule verify-binaries.sh
  # follows for binary names.
  #
  # --packagelist prints TWO paths here, not one: makepkg.conf ships
  # `debug` in OPTIONS, so it also lists a python-flasgger-debug package.
  # That package is never actually produced — this is arch=(any) pure
  # Python, there are no symbols to split out — but the path is listed
  # regardless, and passing both lines to pacman as one argument fails.
  # Filter it out, then confirm what's left is a real file rather than
  # trusting the name.
  _flasgger_pkg="$(cd "$_flasgger_build" && makepkg --packagelist | grep -v -- '-debug-')"
  if [[ $(printf '%s\n' "$_flasgger_pkg" | wc -l) -ne 1 || ! -f $_flasgger_pkg ]]; then
    echo "oniomarchy: expected exactly one built python-flasgger package, got:" >&2
    printf '  %s\n' "$_flasgger_pkg" >&2
    exit 1
  fi
  sudo pacman -U --needed --noconfirm "$_flasgger_pkg"
  unset _flasgger_build _flasgger_pkg
fi
unset _flasgger_src _flasgger_want _flasgger_have
# --- END local python-flasgger build ---

# Installs unmodified. yay sees python-flasgger already satisfied, so it
# never has to resolve it, which is the entire point of the block above.
pkg_aur recon-ng
