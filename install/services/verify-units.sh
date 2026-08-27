echo "==> Verifying real service unit names (pacman -Q / -Ql) — no guessing, per CLAUDE.md"

oniomarchy_state_dir="$HOME/.local/state/oniomarchy"
mkdir -p "$oniomarchy_state_dir"
oniomarchy_services_generated="$oniomarchy_state_dir/services-menu-entries.tsv"
: > "$oniomarchy_services_generated"

while IFS=$'\t' read -r id label package confirm unit1 unit2; do
  [[ -z $id || $id == \#* ]] && continue

  if ! pacman -Qq "$package" >/dev/null 2>&1; then
    echo "==> [services/verify-units] $package not installed — skipping $id" >&2
    continue
  fi

  oniomarchy_units_ok=1
  oniomarchy_clean_units=()
  for unit in "$unit1" "$unit2"; do
    [[ -z $unit ]] && continue
    if [[ $unit == custom:* ]]; then
      # Not package-owned — a unit file we author ourselves and install via
      # install-scripts.sh (e.g. beef.service, since beef-xss ships no unit
      # of its own). Trust it rather than checking pacman ownership.
      oniomarchy_clean_units+=("${unit#custom:}")
      continue
    fi
    if ! pacman -Ql "$package" | grep -qE "/${unit}\$"; then
      echo "==> [services/verify-units] $package doesn't own $unit — skipping $id" >&2
      oniomarchy_units_ok=0
      break
    fi
    oniomarchy_clean_units+=("$unit")
  done
  (( oniomarchy_units_ok )) || continue

  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$label" "$confirm" "${oniomarchy_clean_units[0]:-}" "${oniomarchy_clean_units[1]:-}" >> "$oniomarchy_services_generated"
done < "$ONIOMARCHY_INSTALL/services/services.tsv"

echo "==> Confirmed services written to $oniomarchy_services_generated"
