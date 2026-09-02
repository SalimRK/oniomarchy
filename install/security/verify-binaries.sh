echo "==> Verifying real binary names (pacman -Ql) — no guessing, per CLAUDE.md"

oniomarchy_state_dir="$HOME/.local/state/oniomarchy"
mkdir -p "$oniomarchy_state_dir"
oniomarchy_security_generated="$oniomarchy_state_dir/security-menu-entries.tsv"
: > "$oniomarchy_security_generated"

# Binaries Apps already shows via a real installed .desktop launcher still
# get their own security.* entry (this menu is a complete category view,
# not deduped against Apps — see notes/install-layout.md, 2026-08-25) but
# launch directly instead of through a terminal wrapper, since they're
# already GUI apps.
declare -A oniomarchy_desktop_covered
for desktop_file in /usr/share/applications/*.desktop /opt/*/*.desktop; do
  [[ -f $desktop_file ]] || continue
  exec_line=$(grep -m1 '^Exec=' "$desktop_file" 2>/dev/null || true)
  exec_line=${exec_line#Exec=}
  # The Exec target is not always the first word. The desktop-entry spec
  # allows the command to be wrapped, and autopsy ships
  # `Exec=env TSK_HOME=/bin /usr/bin/autopsy`. Reading word one there
  # records `env` as a GUI binary and never records `autopsy`, so a full
  # NetBeans forensics GUI fell through to the terminal help entry
  # (found on a real run 2026-09-02, the first with autopsy installed).
  # Skip a leading `env` and any VAR=value assignments after it.
  read -ra exec_words <<<"$exec_line"
  exec_idx=0
  [[ ${exec_words[0]:-} == env ]] && exec_idx=1
  while [[ ${exec_words[$exec_idx]:-} == [A-Za-z_]*=* ]]; do
    exec_idx=$((exec_idx + 1))
  done
  exec_bin=${exec_words[$exec_idx]:-}
  exec_bin=${exec_bin##*/}
  [[ -n $exec_bin ]] && oniomarchy_desktop_covered["$exec_bin"]=1
done

# Action for a given binary: direct launch (no terminal) if it's a known
# GUI app via a real .desktop Exec= target, otherwise open a terminal
# showing the tool's own usage and hand off to an interactive shell.
#
# CLI entries deliberately do NOT run the tool bare. Nearly every tool
# here needs arguments, so a bare run just prints an error — and the ones
# that touch raw sockets (bettercap, the aircrack-ng suite) die with
# "Permission Denied" before showing anything useful. oniomarchy-tool-help
# discovers the tool's real help flag at run time and prints that instead;
# see install/security/tool-help.sh.
oniomarchy_action_for() {
  local b="$1"
  if [[ -n ${oniomarchy_desktop_covered[$b]:-} ]]; then
    printf 'uwsm-app -- %s' "$b"
  else
    printf "omarchy-launch-tui bash -c 'oniomarchy-tool-help %s; exec bash'" "$b"
  fi
}

oniomarchy_row_count=0

while IFS=$'\t' read -r pkg category mode extra; do
  [[ -z $pkg || $pkg == \#* ]] && continue
  oniomarchy_row_count=$((oniomarchy_row_count + 1))

  case "$mode" in
    skip)
      continue
      ;;
    manual)
      # A single named binary, verified via `command -v` (PATH lookup)
      # rather than `pacman -Qi`/`pacman -Ql` — same verify-don't-guess
      # rule, different source of truth. Covers two different cases:
      #   - not a pacman package at all (e.g. hexstrike-ai): a git-clone+
      #     venv install script placed $extra on PATH itself.
      #   - a pacman-owned binary that's cross-listed into a second
      #     category on purpose (e.g. msfmcpd, already covered by
      #     metasploit's own `auto` row under Exploitation Tools, also
      #     listed standalone under AI Tools) — `command -v` finds it
      #     wherever pacman put it, no need to re-scan/duplicate the rest
      #     of that package's binaries the way a second `auto` row would.
      if ! command -v "$extra" >/dev/null 2>&1; then
        echo "==> [security/verify-binaries] $pkg: '$extra' not found on PATH — skipping (manual mode never guesses)" >&2
        continue
      fi
      printf 'ENTRY\t%s\t-\t%s\t%s\t%s\t%s\n' \
        "$category" "$extra" "$extra" "$(oniomarchy_action_for "$extra")" "$pkg" \
        >> "$oniomarchy_security_generated"
      continue
      ;;
    data|collapse|auto) ;;
    *)
      echo "==> [security/verify-binaries] $pkg: unknown mode '$mode' in categories.tsv — skipping" >&2
      continue
      ;;
  esac

  if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
    echo "==> [security/verify-binaries] $pkg not installed yet — skipping (no guessing at binary names for uninstalled packages)" >&2
    continue
  fi

  case "$mode" in
    data)
      printf 'ENTRY\t%s\t-\t%s\t%s\t%s\t%s\n' \
        "$category" "$pkg" "$pkg" "uwsm-app -- nautilus '$extra'" "$pkg" \
        >> "$oniomarchy_security_generated"
      continue
      ;;
    collapse)
      printf 'ENTRY\t%s\t-\t%s\t%s\t%s\t%s\n' \
        "$category" "$extra" "$extra" "omarchy-launch-tui bash -c 'oniomarchy-tool-help $extra; exec bash'" "$pkg" \
        >> "$oniomarchy_security_generated"
      continue
      ;;
  esac

  mapfile -t oniomarchy_pkg_bins < <(
    pacman -Ql "$pkg" | awk '{print $2}' | while read -r f; do
      [[ $f == /usr/bin/* && -f $f && -x $f ]] && basename "$f"
    done | sort -u
  )

  if (( ${#oniomarchy_pkg_bins[@]} == 0 )); then
    # No /usr/bin binary at all (e.g. a script installed under /opt with
    # only a .desktop launcher, like supersdr's Exec=/opt/supersdr/supersdr.py)
    # — fall back to launching the package's own real .desktop file via
    # gtk-launch (owned by gtk3, already part of the desktop stack) instead
    # of silently dropping the package from the menu.
    oniomarchy_pkg_desktop=$(pacman -Ql "$pkg" | awk '{print $2}' | grep '\.desktop$' | head -1)
    if [[ -n $oniomarchy_pkg_desktop ]]; then
      oniomarchy_desktop_id=$(basename "$oniomarchy_pkg_desktop")
      oniomarchy_desktop_id="${oniomarchy_desktop_id%.desktop}"
      printf 'ENTRY\t%s\t-\t%s\t%s\t%s\t%s\n' \
        "$category" "$pkg" "$pkg" "uwsm-app -- gtk-launch $oniomarchy_desktop_id" "$pkg" \
        >> "$oniomarchy_security_generated"
    else
      echo "==> [security/verify-binaries] $pkg: no /usr/bin binary and no .desktop file — skipping" >&2
    fi
  elif (( ${#oniomarchy_pkg_bins[@]} == 1 )); then
    b="${oniomarchy_pkg_bins[0]}"
    id_slug="${b//./_}"
    printf 'ENTRY\t%s\t-\t%s\t%s\t%s\t%s\n' \
      "$category" "$id_slug" "$b" "$(oniomarchy_action_for "$b")" "$pkg" \
      >> "$oniomarchy_security_generated"
  else
    printf 'SUBCAT\t%s\t%s\t%s\n' "$category" "$pkg" "$pkg" >> "$oniomarchy_security_generated"
    for b in "${oniomarchy_pkg_bins[@]}"; do
      id_slug="${b//./_}"
      printf 'ENTRY\t%s\t%s\t%s\t%s\t%s\t-\n' \
        "$category" "$pkg" "$id_slug" "$b" "$(oniomarchy_action_for "$b")" \
        >> "$oniomarchy_security_generated"
    done
  fi
done < "$ONIOMARCHY_INSTALL/security/categories.tsv"

echo "==> Checked $oniomarchy_row_count packages from categories.tsv; wrote $oniomarchy_security_generated"
