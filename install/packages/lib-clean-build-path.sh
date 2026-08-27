# AUR builds must never run against a version-manager shim (mise, nvm,
# pyenv, etc.) instead of the real system toolchain a PKGBUILD's
# makedepends actually installed. On this machine, `mise` shims `python`
# ahead of the system one in PATH; letting an AUR build() run under it
# doesn't just miss packages (fixable by installing them into mise's
# Python) — `python -m installer -d "$pkgdir"` silently ignored the
# destdir under mise's non-standard absolute install scheme and wrote
# theharvester-git's real binaries straight onto the live filesystem
# under ~/.local/share/mise/, root-owned, instead of into the fakeroot
# sandbox (see notes/install-issues.md fix #3/#4 history — that fix was
# wrong, this replaces it).
#
# Filters out mise's PATH entries specifically rather than replacing
# PATH wholesale, so it doesn't clobber anything else legitimately
# prepended to PATH — notably CLAUDE.md's own mocked-`omarchy` test
# harness (`PATH="$tmpdir:$PATH" bash install.sh`), which an earlier,
# wholesale-replace version of this file broke.
_oniomarchy_clean_path=""
IFS=':' read -ra _oniomarchy_path_parts <<< "$PATH"
for _oniomarchy_path_part in "${_oniomarchy_path_parts[@]}"; do
  case "$_oniomarchy_path_part" in
    */mise/*) continue ;;
  esac
  _oniomarchy_clean_path="${_oniomarchy_clean_path:+$_oniomarchy_clean_path:}$_oniomarchy_path_part"
done
export PATH="$_oniomarchy_clean_path"
unset _oniomarchy_clean_path _oniomarchy_path_parts _oniomarchy_path_part
