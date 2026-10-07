# Shared by install/security/menu.sh, install/services/menu.sh and
# install/trigger/menu.sh: merges one generated, BEGIN/END-marked block into
# ~/.config/omarchy/extensions/omarchy-menu.jsonc.
#
#   oniomarchy_merge_menu_block <name> <block-file> <menu-jsonc>
#
# <name> is the word inside the markers ("security" for
# `// BEGIN oniomarchy security menu`). Any existing block with those
# markers is dropped and the new one is inserted just before the file's
# closing `}`, so reruns replace rather than duplicate.
#
# Three guards, all from issue #4, where a fresh install lost every user
# menu entry:
#
# 1. The comma. The entry above the insertion point is often the user's
#    own last entry, valid without a trailing comma. Inserting under it
#    produced `{...}\n  "security": ...` — invalid. So that line gets a
#    comma when it lacks one. Always safe: Omarchy's reader
#    (stripJsonc() in /usr/share/omarchy/shell/plugins/menu/MenuModel.js)
#    drops a comma that sits before `}`. A file already broken this way by
#    an earlier run is repaired by the next one, since the missing comma
#    is always on the line right above where the block goes back in.
#
# 2. Validation before replacing. Omarchy's parser returns an empty menu
#    on any parse error — no message — so a broken file silently takes
#    away the user's own overrides along with ours. The merged file is
#    checked the way Omarchy reads it (full-line // comments removed,
#    commas before } or ] removed, then strict JSON) and never moved into
#    place if it fails.
#
# 3. A backup. The file as it was before this builder touched it is kept
#    at ~/.local/state/oniomarchy/menu-backup/omarchy-menu.before-<name>.jsonc
#    — outside extensions/, so Omarchy never reads it.

# Exit 0 when <file> parses the way Omarchy's menu reads it. jq and perl
# are both dependencies of the omarchy package itself.
oniomarchy_menu_jsonc_valid() {
  perl -0777 -pe 's#^\s*//[^\n]*(\n|$)##mg; s#,(\s*[}\]])#$1#g' "$1" |
    jq -e 'type == "object"' >/dev/null 2>&1
}

oniomarchy_merge_menu_block() {
  local name="$1" block_file="$2" menu_jsonc="$3"
  local merged backup_dir

  merged=$(mktemp) || return 1

  awk -v blockfile="$block_file" -v name="$name" '
    BEGIN {
      begin_marker = "// BEGIN oniomarchy " name " menu"
      end_marker = "// END oniomarchy " name " menu"
      while ((getline line < blockfile) > 0) block[++nblock] = line
    }
    index($0, begin_marker) { in_block = 1; next }
    index($0, end_marker) { in_block = 0; next }
    in_block { next }
    { lines[++n] = $0 }
    END {
      # The first line that is only a closing brace closes the top-level
      # object — the same insertion point every builder has always used.
      close_at = 0
      for (i = 1; i <= n; i++)
        if (lines[i] ~ /^}[[:space:]]*$/) { close_at = i; break }
      if (!close_at) exit 2

      # Last real line above it: not blank, not a whole-line comment.
      for (i = close_at - 1; i >= 1; i--) {
        if (lines[i] ~ /^[[:space:]]*$/ || lines[i] ~ /^[[:space:]]*\/\//) continue
        sub(/[[:space:]]+$/, "", lines[i])
        if (lines[i] !~ /[,{]$/) lines[i] = lines[i] ","
        break
      }

      for (i = 1; i < close_at; i++) print lines[i]
      for (i = 1; i <= nblock; i++) print block[i]
      for (i = close_at; i <= n; i++) print lines[i]
    }
  ' "$menu_jsonc" > "$merged"
  local awk_rc=$?

  if (( awk_rc == 2 )); then
    echo "==> [$name/menu] $menu_jsonc has no closing '}' line — left untouched" >&2
    rm -f "$merged"
    return 1
  elif (( awk_rc != 0 )); then
    echo "==> [$name/menu] could not merge into $menu_jsonc — left untouched" >&2
    rm -f "$merged"
    return 1
  fi

  if ! oniomarchy_menu_jsonc_valid "$merged"; then
    echo "==> [$name/menu] the merged menu would not parse, so $menu_jsonc was left untouched." >&2
    echo "    Omarchy drops the whole file when it cannot parse it. Check it for a" >&2
    echo "    missing comma or a comment at the end of a line, then rerun." >&2
    rm -f "$merged"
    return 1
  fi

  backup_dir="$HOME/.local/state/oniomarchy/menu-backup"
  if mkdir -p "$backup_dir"; then
    cp -f "$menu_jsonc" "$backup_dir/omarchy-menu.before-$name.jsonc"
  fi

  # cat into the existing file rather than mv: keeps its inode, owner and
  # permissions, and a symlinked extensions file stays a symlink.
  cat "$merged" > "$menu_jsonc"
  local rc=$?
  rm -f "$merged"
  return "$rc"
}
