# Pack resolution — shared by install.sh (validation, --list-packs) and
# apps/all.sh (filtering the leaf list before it runs). See
# notes/pack-design.md for the full design.
#
# One tag per leaf, no manifest: a leaf carries `# pack: core`,
# `# pack: <category>`, or no tag at all (an "extra", reachable only via
# `--pack <category>-all` or `--pack all`). Categories are just the
# directory names under install/apps/ (excluding lib/), so nothing here
# needs to be kept in sync when a category or leaf is added.

_ONIOMARCHY_APPS_DIR="${ONIOMARCHY_APPS:-$ONIOMARCHY_INSTALL/apps}"

oniomarchy_pack_categories() {
  find "$_ONIOMARCHY_APPS_DIR" -mindepth 1 -maxdepth 1 -type d \
    -not -name lib -printf '%f\n' | sort
}

oniomarchy_pack_all_leaves() {
  find "$_ONIOMARCHY_APPS_DIR" -mindepth 2 -name '*.sh' \
    -not -path "$_ONIOMARCHY_APPS_DIR/lib/*" \
    -not -path '*/files/*' | sort
}

oniomarchy_pack_leaf_category() {
  basename "$(dirname "$1")"
}

# Empty output means untagged (an "extra").
oniomarchy_pack_leaf_tag() {
  grep -m1 -oP '^#\s*pack:\s*\K\S+' "$1" || true
}

oniomarchy_pack_valid_name() {
  local name="$1" cat
  [[ $name == core || $name == all ]] && return 0
  while IFS= read -r cat; do
    [[ $name == "$cat" || $name == "${cat}-all" ]] && return 0
  done < <(oniomarchy_pack_categories)
  return 1
}

oniomarchy_pack_valid_names_list() {
  { echo core; echo all
    oniomarchy_pack_categories | while IFS= read -r cat; do
      echo "$cat"
      echo "${cat}-all"
    done
  }
}

# Prints the union of leaves selected by the given (already-validated)
# pack names, one per line, sorted and deduped. Never adds anything not
# named — `--pack sdr` never pulls in the rest of core.
oniomarchy_pack_resolve() {
  local leaf category tag pack cat
  local -A selected=()
  while IFS= read -r leaf; do
    category="$(oniomarchy_pack_leaf_category "$leaf")"
    tag="$(oniomarchy_pack_leaf_tag "$leaf")"
    for pack in "$@"; do
      case "$pack" in
        core)
          [[ $tag == core ]] && selected["$leaf"]=1
          ;;
        all)
          selected["$leaf"]=1
          ;;
        *-all)
          cat="${pack%-all}"
          [[ $category == "$cat" ]] && selected["$leaf"]=1
          ;;
        *)
          if [[ $category == "$pack" ]] && [[ $tag == core || $tag == "$pack" ]]; then
            selected["$leaf"]=1
          fi
          ;;
      esac
    done
  done < <(oniomarchy_pack_all_leaves)
  (( ${#selected[@]} == 0 )) && return 0
  printf '%s\n' "${!selected[@]}" | sort
}
