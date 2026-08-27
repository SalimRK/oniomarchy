echo "==> Installing security webapps (omarchy webapp install)..."

oniomarchy_webapps_tsv="$ONIOMARCHY_INSTALL/security/webapps.tsv"
oniomarchy_webapps_installed=0
oniomarchy_webapps_skipped=0
oniomarchy_webapps_failed=0

while IFS=$'\t' read -r id_slug label url tactic icon; do
  [[ -z $id_slug || $id_slug == \#* ]] && continue

  oniomarchy_webapp_desktop="$HOME/.local/share/applications/$label.desktop"
  if [[ -f $oniomarchy_webapp_desktop ]]; then
    echo "==> [security/webapps] $label already installed — skipping"
    oniomarchy_webapps_skipped=$((oniomarchy_webapps_skipped + 1))
    continue
  fi

  # "-" (or unset) means auto-fetch: an empty 3rd arg takes
  # omarchy-webapp-install's non-interactive branch (name/url/icon all
  # supplied) while still leaving the icon unset, which triggers its own
  # auto-favicon-fetch (apple-touch-icon -> well-known path -> Google's
  # favicon service) — same as the "Install > Web App" menu flow when no
  # icon is given, just non-interactive. Any other value in the icon
  # column (a URL, file path, or bundled icon-theme name) is passed
  # straight through instead, for sites with no auto-fetchable icon (see
  # webapps.tsv's header comment).
  [[ -z $icon || $icon == "-" ]] && icon=""

  if omarchy webapp install "$label" "$url" "$icon"; then
    oniomarchy_webapps_installed=$((oniomarchy_webapps_installed + 1))
  else
    echo "==> [security/webapps] $label: install failed (icon fetch or bad URL?) — skipping" >&2
    oniomarchy_webapps_failed=$((oniomarchy_webapps_failed + 1))
  fi
done < "$oniomarchy_webapps_tsv"

echo "==> Webapps: $oniomarchy_webapps_installed installed, $oniomarchy_webapps_skipped already present, $oniomarchy_webapps_failed failed"
