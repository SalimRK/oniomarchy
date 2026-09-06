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
pkg_repo recon-ng
