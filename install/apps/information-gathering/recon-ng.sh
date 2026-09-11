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
# no [oniomarchy] tree there, pkg_repo would fall back to the AUR, and the
# AUR still has no python-flasgger. But flasgger IS on PyPI — being
# pip-only is exactly what blocks yay and exactly what a venv handles. So
# on aarch64 we skip the AUR and install recon-ng git+venv, like
# ai-tools/hexstrike-ai.sh: `pip install -r REQUIREMENTS` pulls flasgger
# and the other 12 deps straight from PyPI (verified: installs and runs).
# x86_64 is untouched — it still installs the signed binary from the repo.
#
# Menu note (as in theharvester.sh): verify-binaries.sh discovers menu
# entries from installed packages, so a venv tool is not auto-added to the
# Security menu on aarch64. The /usr/local/bin wrapper makes `recon-ng`
# runnable from a terminal; a categories.tsv manual-mode row (to also list
# it in the menu) is deferred so the x86_64 menu is not disturbed.
if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
  _oniomarchy_clean_build_path
  _rng_dir="$HOME/.local/share/oniomarchy/recon-ng"

  if [[ -d $_rng_dir/.git ]]; then
    echo "==> recon-ng already cloned — pulling latest"
    git -C "$_rng_dir" pull --ff-only
  else
    echo "==> Cloning recon-ng (aarch64: git+venv, no AUR)"
    mkdir -p "$(dirname "$_rng_dir")"
    git clone --depth 1 https://github.com/lanmaster53/recon-ng.git "$_rng_dir"
  fi

  [[ -x $_rng_dir/env/bin/python3 ]] || python3 -m venv "$_rng_dir/env"

  # Stamp the installed commit so a re-run skips pip when HEAD hasn't moved
  # (recon-ng has no `--needed`), same reasoning as hexstrike-ai.sh.
  _rng_stamp="$HOME/.local/state/oniomarchy/recon-ng-requirements.stamp"
  _rng_head="$(git -C "$_rng_dir" rev-parse HEAD 2>/dev/null || true)"
  if [[ -r $_rng_stamp && "$(cat "$_rng_stamp")" == "$_rng_head" ]]; then
    echo "==> recon-ng deps already installed for ${_rng_head:0:12} — skipping pip"
  else
    echo "==> Installing recon-ng's Python dependencies into its venv"
    CC=gcc CXX=g++ TMPDIR=/var/tmp "$_rng_dir/env/bin/pip" install -r "$_rng_dir/REQUIREMENTS"
    mkdir -p "$(dirname "$_rng_stamp")"
    printf '%s\n' "$_rng_head" > "$_rng_stamp"
  fi

  if ! cmp -s "$ONIOMARCHY_APP_DIR/files/recon-ng-venv-wrapper.sh" /usr/local/bin/recon-ng; then
    sudo install -Dm755 "$ONIOMARCHY_APP_DIR/files/recon-ng-venv-wrapper.sh" /usr/local/bin/recon-ng
    echo "==> recon-ng wrapper installed to /usr/local/bin"
  fi

  unset _rng_dir _rng_stamp _rng_head
else
  pkg_repo recon-ng
fi
