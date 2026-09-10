# recon-ng — Information Gathering
#
# Unblocked 2026-09-01, and simplified back to one line on 2026-09-06.
#
# The AUR package was never the problem: recon-ng 5.1.2 is maintained and
# matches upstream's newest tag. Exactly one of its 13 dependencies,
# python-flasgger, existed in neither the official repos nor the AUR —
# pip-only — and `yay` cannot resolve a pip-only package, so the whole
# install failed on that one missing ingredient. This leaf therefore used
# to carry a full PKGBUILD and build python-flasgger locally with makepkg,
# the only place in this repo that ever did that.
#
# [oniomarchy] now publishes python-flasgger as a signed binary, and
# recon-ng's own packaged PKGBUILD lists it in depends=(), so pacman pulls
# it in on its own. The recipe did not disappear — it moved to where it
# belongs, oniomarchy-pkgs/pkgs/python-flasgger/PKGBUILD, which is also
# the copy that would be published if it ever goes to the AUR.
#
# Which is precisely why aarch64 is back to the 2026-09-01 problem: with
# no [oniomarchy] tree there, pkg_repo falls back to the AUR, and the AUR
# still has no python-flasgger. The other 12 dependencies all resolve, so
# yay fails at resolution in seconds — cheap enough to keep attempting,
# and it starts working the moment python-flasgger is published upstream.
pkg_repo recon-ng || {
  rc=$?
  if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
    cat >&2 <<'EOF'
oniomarchy: recon-ng cannot be built from the AUR right now.
  Its dependency python-flasgger is pip-only — it exists in neither the
  official repos nor the AUR — and yay cannot resolve a package that does
  not exist. On x86_64 [oniomarchy] publishes it as a signed binary; there
  is no aarch64 tree, so nothing supplies it here. Every other dependency
  resolves (python-flask-restful, python-dicttoxml, python-unicodecsv and
  python-rq from the AUR, the rest from extra).
  The fix is a publish, not a code change here: push
  oniomarchy-pkgs/pkgs/python-flasgger/PKGBUILD to the AUR — that recipe
  was written to be the copy that goes there — or add an aarch64 tree to
  [oniomarchy].
EOF
  fi
  exit "$rc"
}
