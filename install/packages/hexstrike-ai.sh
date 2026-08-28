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
# lib-clean-build-path.sh) since this invokes python3/pip directly — same
# risk of silently building against mise's Python instead of the system
# one that bit theharvester-git and wfuzz.
source "$ONIOMARCHY_INSTALL/packages/lib-clean-build-path.sh"

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

echo "==> Installing hexstrike-ai's Python dependencies"
"$_hexstrike_dir/hexstrike-env/bin/pip" install --no-cache-dir -r "$_hexstrike_dir/requirements.txt"

sudo install -Dm755 "$ONIOMARCHY_INSTALL/packages/hexstrike-server-wrapper.sh" /usr/local/bin/hexstrike-server
echo "==> hexstrike-server installed to /usr/local/bin"

unset _hexstrike_dir

echo "==> hexstrike-ai does not install the 150+ tools it drives — those are"
echo "    this repo's own tools (nmap, gobuster, ffuf, nikto, etc.), already"
echo "    installed by the rest of install/packages/. See notes/pentest-tools.md."
