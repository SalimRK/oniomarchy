# hexstrike-ai has no Arch/AUR package — confirmed 2026-08-28 (no `yay -Ss
# hexstrike` hit). Install is git-clone + venv, per upstream's own README
# (github.com/0x4m4/hexstrike-ai): clone, `python3 -m venv hexstrike-env`,
# `pip install -r requirements.txt`, then run `hexstrike_server.py`
# (argparse-based: --debug, --port, default port 8888).
#
# Cloned to a user-owned XDG data dir, not /opt — /opt in this repo is
# reserved for root-owned pacman/AUR package payloads (see python-garak,
# armitage-git, etc.); this is a plain git clone, not a package.
#
# PATH is cleaned of mise the same way AUR builds are (see
# lib/clean-build-path.sh) since this invokes python3/pip directly — same
# risk of silently building against mise's Python instead of the system
# one that bit theharvester-git and wfuzz.
_oniomarchy_clean_build_path

_hexstrike_dir="$HOME/.local/share/oniomarchy/hexstrike-ai"

if [[ -d $_hexstrike_dir/.git ]]; then
  echo "==> hexstrike-ai already cloned — pulling latest"
  git -C "$_hexstrike_dir" pull --ff-only
else
  echo "==> Cloning hexstrike-ai"
  mkdir -p "$(dirname "$_hexstrike_dir")"
  git clone https://github.com/0x4m4/hexstrike-ai.git "$_hexstrike_dir"
fi

if [[ ! -x $_hexstrike_dir/hexstrike-env/bin/python3 ]]; then
  echo "==> Creating hexstrike-ai's venv"
  python3 -m venv "$_hexstrike_dir/hexstrike-env"
fi

# Skip the dependency install when nothing can have changed.
#
# This is the only app whose install is not a package operation, so it has
# no `--needed` to make it a no-op: pip walks all 142 requirements across a
# 762 MB / 28k-file venv every run. Measured on a real install: 72s cold,
# ~5s warm, with zero packages actually downloaded.
#
# The stamp records the commit whose requirements were installed
# *successfully* — the leaf runs under `set -e`, so a pip that fails or is
# interrupted never reaches the write and the next run retries properly.
# Comparing against git rather than hashing requirements.txt means the
# check is exact: if HEAD has not moved, nothing in the tree has changed.
_hexstrike_stamp="$HOME/.local/state/oniomarchy/hexstrike-ai-requirements.stamp"
_hexstrike_head="$(git -C "$_hexstrike_dir" rev-parse HEAD 2>/dev/null || true)"

if [[ -x $_hexstrike_dir/hexstrike-env/bin/pip && -n $_hexstrike_head ]] &&
   [[ -r $_hexstrike_stamp && "$(cat "$_hexstrike_stamp")" == "$_hexstrike_head" ]]; then
  echo "==> hexstrike-ai's dependencies already installed for ${_hexstrike_head:0:12} — skipping pip"
else
  echo "==> Installing hexstrike-ai's Python dependencies"
  # No --no-cache-dir: it buys nothing when every requirement is already
  # satisfied, and forces a re-download of anything that isn't.
  "$_hexstrike_dir/hexstrike-env/bin/pip" install -r "$_hexstrike_dir/requirements.txt"
  mkdir -p "$(dirname "$_hexstrike_stamp")"
  printf '%s\n' "$_hexstrike_head" > "$_hexstrike_stamp"
fi

# Only touch /usr/local/bin when the wrapper actually differs, so a
# no-op run doesn't take a root write.
if ! cmp -s "$ONIOMARCHY_APP_DIR/files/hexstrike-server-wrapper.sh" /usr/local/bin/hexstrike-server; then
  sudo install -Dm755 "$ONIOMARCHY_APP_DIR/files/hexstrike-server-wrapper.sh" /usr/local/bin/hexstrike-server
  echo "==> hexstrike-server installed to /usr/local/bin"
fi

unset _hexstrike_stamp _hexstrike_head

unset _hexstrike_dir

echo "==> hexstrike-ai does not install the 150+ tools it drives — those are"
echo "    this repo's own tools (nmap, gobuster, ffuf, nikto, etc.), already"
echo "    installed by the rest of install/apps/. See notes/pentest-tools.md."
