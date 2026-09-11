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
# None of that reaches aarch64: there is no [oniomarchy] tree, and building
# theharvester-git straight from the AUR fails on that same flit_core cap —
# python-aiomultiprocess is pinned to 0.9.0 (obsolete [tool.flit.metadata],
# flagged out-of-date in the AUR since 2025-03-03) and won't build against
# flit_core >= 4. So on aarch64 we skip the AUR entirely and install
# theHarvester the way ai-tools/hexstrike-ai.sh installs its tool: a
# user-owned git clone + venv. theHarvester upstream long ago dropped
# aiomultiprocess, so a plain `pip install .` pulls only deps that build
# cleanly on aarch64 (verified: installs and `theHarvester --help` runs).
# x86_64 is untouched — it still installs the signed binary from the repo.
#
# One consequence to note: install/security/verify-binaries.sh discovers
# menu entries from installed *packages* (pacman -Ql), so a venv tool is
# not auto-added to the Security menu on aarch64 (same as hexstrike-ai).
# The wrapper on /usr/local/bin makes `theHarvester` runnable from a
# terminal regardless; wiring it into the menu would mean a manual-mode
# row in categories.tsv, deferred so the x86_64 menu is not disturbed.
if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
  # PATH cleaned of mise, and CC/CXX pinned + TMPDIR moved off the 2 GB
  # tmpfs, for the same reasons hexstrike-ai.sh and lib/pkg.sh's pkg_aur
  # do: build against the system toolchain, and don't invoke the distcc
  # wrapper that Arch Linux ARM bakes into the Python sysconfig's CXX.
  _oniomarchy_clean_build_path
  _th_dir="$HOME/.local/share/oniomarchy/theharvester"

  if [[ -d $_th_dir/.git ]]; then
    echo "==> theHarvester already cloned — pulling latest"
    git -C "$_th_dir" pull --ff-only
  else
    echo "==> Cloning theHarvester (aarch64: git+venv, no AUR)"
    mkdir -p "$(dirname "$_th_dir")"
    git clone --depth 1 https://github.com/laramies/theHarvester.git "$_th_dir"
  fi

  [[ -x $_th_dir/env/bin/python3 ]] || python3 -m venv "$_th_dir/env"

  # Stamp the installed commit so a re-run skips pip when HEAD hasn't moved
  # — theHarvester has no `--needed`, same reasoning as hexstrike-ai.sh.
  _th_stamp="$HOME/.local/state/oniomarchy/theharvester-requirements.stamp"
  _th_head="$(git -C "$_th_dir" rev-parse HEAD 2>/dev/null || true)"
  if [[ -r $_th_stamp && "$(cat "$_th_stamp")" == "$_th_head" ]]; then
    echo "==> theHarvester deps already installed for ${_th_head:0:12} — skipping pip"
  else
    echo "==> Installing theHarvester into its venv"
    CC=gcc CXX=g++ TMPDIR=/var/tmp "$_th_dir/env/bin/pip" install "$_th_dir"
    mkdir -p "$(dirname "$_th_stamp")"
    printf '%s\n' "$_th_head" > "$_th_stamp"
  fi

  if ! cmp -s "$ONIOMARCHY_APP_DIR/files/theharvester-venv-wrapper.sh" /usr/local/bin/theHarvester; then
    sudo install -Dm755 "$ONIOMARCHY_APP_DIR/files/theharvester-venv-wrapper.sh" /usr/local/bin/theHarvester
    echo "==> theHarvester wrapper installed to /usr/local/bin"
  fi

  unset _th_dir _th_stamp _th_head
else
  pkg_repo theharvester-git
fi
