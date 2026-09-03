# firefox — Web Application Analysis
# pack: core
#
# Installs Firefox as Oniomarchy's *security* browser and configures it the
# way you would by hand anyway: DuckDuckGo, permanent private browsing,
# clear-on-exit, no password prompts, ask-where-to-save, and five
# extensions. Chromium stays Omarchy's default browser and is not touched.
#
# Design, and the verified-against-Mozilla reasoning behind every policy
# key: notes/firefox-setup.md. Read that before changing anything here.
#
# Everything is done through ONE file, /etc/firefox/policies/policies.json —
# Mozilla's supported enterprise mechanism. It is system-wide (all Firefox
# profiles), which is deliberate: this is the user's normal Firefox setup,
# not a throwaway pentest profile.
#
# Three availability facts this file depends on, each read from Mozilla's
# policy reference rather than recalled — none are guesses, and all three
# would fail silently rather than loudly if wrong:
#
#   * `SearchEngines` was ESR-only for years and reached regular Firefox
#     only at 139. Below that there is NO supported way to set the default
#     engine, so the version guard further down is real, not ceremony.
#   * `ExtensionSettings.private_browsing` (Firefox 136+) is what keeps the
#     extensions working at all: permanent private browsing otherwise
#     disables every one of them, silently undoing half this file.
#   * The `Preferences` policy does NOT accept a blanket `privacy.` prefix.
#     Only specific privacy prefs are allowlisted, and
#     privacy.globalprivacycontrol.enabled happens to be one (Firefox 127+).
#     A sibling privacy.* pref added here later will do nothing at all.

pkg_official firefox

# The public site. Temporary domain until oniomarchy.com is bought — change
# this one line then, it is the only place either URL appears.
oniomarchy_site_url="https://oniomarchy.sraclb.com"
oniomarchy_repo_url="https://github.com/SalimRK/oniomarchy"

# --- version guard --------------------------------------------------------
#
# A policies.json containing a key this Firefox doesn't understand is not
# an error: Firefox ignores the unknown key and applies the rest. So an old
# Firefox degrades quietly rather than failing, and the only way to know is
# to say so here.
oniomarchy_ff_major=$(firefox --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
if [[ -n $oniomarchy_ff_major ]] && (( oniomarchy_ff_major < 139 )); then
  echo "==> Firefox $oniomarchy_ff_major is older than 139 — the SearchEngines policy"
  echo "    did not reach non-ESR Firefox until 139, so the DuckDuckGo default will"
  echo "    be ignored. Every other policy below still applies."
fi

# --- bookmarks ------------------------------------------------------------
#
# Rendered from install/security/webapps.tsv rather than hardcoded into the
# template. That file is already the single source of truth for these URLs
# (it drives the desktop launchers install-webapps.sh creates); a second
# hand-maintained copy would drift the moment either is edited. Same
# reasoning as discovering app leaves with `find` instead of a manifest.

# JSON-string-escape a value (backslash and double-quote only), matching
# oniomarchy_jesc in install/*/menu.sh.
oniomarchy_jesc() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

oniomarchy_bookmark_row() {
  printf '      {"Title":"%s","URL":"%s","Placement":"toolbar","Folder":"Oniomarchy"},\n' \
    "$(oniomarchy_jesc "$1")" "$(oniomarchy_jesc "$2")"
}

oniomarchy_bookmarks_file=$(mktemp)
oniomarchy_policies_file=$(mktemp)
trap 'rm -f "$oniomarchy_bookmarks_file" "$oniomarchy_policies_file"' EXIT

{
  echo '    "Bookmarks": ['
  oniomarchy_bookmark_row "Oniomarchy" "$oniomarchy_site_url"
  oniomarchy_bookmark_row "Oniomarchy on GitHub" "$oniomarchy_repo_url"

  oniomarchy_webapps_tsv="$ONIOMARCHY_INSTALL/security/webapps.tsv"
  oniomarchy_bookmark_count=2
  if [[ -f $oniomarchy_webapps_tsv ]]; then
    while IFS=$'\t' read -r _slug label url _tactic _icon; do
      [[ -z ${label:-} || -z ${url:-} ]] && continue
      oniomarchy_bookmark_row "$label" "$url"
      oniomarchy_bookmark_count=$(( oniomarchy_bookmark_count + 1 ))
    done < <(grep -v '^[[:space:]]*#' "$oniomarchy_webapps_tsv" | grep -v '^[[:space:]]*$')
  else
    echo "==> webapps.tsv not found — bookmarking only the project links" >&2
  fi

  # Trailing comma on the last row is invalid JSON, so close the array by
  # rewriting it below rather than trying to know which row was last.
  echo '    ],'
} > "$oniomarchy_bookmarks_file"

# Drop the comma from the final bookmark row (the line before the closing
# `],`). sed on the second-to-last line is fragile; do it by line number.
oniomarchy_last_row=$(( $(wc -l < "$oniomarchy_bookmarks_file") - 1 ))
sed -i "${oniomarchy_last_row}s/},$/}/" "$oniomarchy_bookmarks_file"

# --- render ---------------------------------------------------------------

awk -v bookmarks="$oniomarchy_bookmarks_file" -v homepage="$oniomarchy_site_url" '
  /@BOOKMARKS@/ {
    while ((getline line < bookmarks) > 0) print line
    next
  }
  { gsub(/@HOMEPAGE@/, homepage); print }
' "$ONIOMARCHY_APP_DIR/files/policies.json.in" > "$oniomarchy_policies_file"

# A malformed policies.json is ignored SILENTLY by Firefox — no error, no
# warning, the whole configuration simply never applies. That makes this
# check the difference between a visible failure and a mystery. python3 is
# used only here, and only as a validator, so a machine without it still
# gets a correct install.
if command -v python3 >/dev/null 2>&1; then
  if ! python3 -m json.tool "$oniomarchy_policies_file" >/dev/null 2>&1; then
    echo "==> Generated policies.json is not valid JSON — refusing to install it." >&2
    exit 1
  fi
else
  echo "==> python3 not available — skipping the policies.json validity check" >&2
fi

sudo install -Dm644 "$oniomarchy_policies_file" /etc/firefox/policies/policies.json
echo "==> Firefox policy installed ($oniomarchy_bookmark_count bookmarks) to /etc/firefox/policies/policies.json"

# --- FoxyProxy ------------------------------------------------------------
#
# FoxyProxy's own proxy list lives in extension storage with no documented
# file to seed, so it cannot be installed by policy the way the extension
# itself can. What ships instead is an importable settings file, validated
# against FoxyProxy 8's real schema (src/content/schema.json in its repo —
# note `port` is a STRING there and the top level is an object with
# required `mode`/`data` keys; a bare array or a numeric port is rejected).
oniomarchy_share_dir="$HOME/.local/share/oniomarchy/firefox"
install -Dm644 "$ONIOMARCHY_APP_DIR/files/foxyproxy-oniomarchy.json" \
  "$oniomarchy_share_dir/foxyproxy-oniomarchy.json"

cat <<EOF
==> Firefox configured. Four things still need you, once:

    1. Import FoxyProxy's proxies (Burp 8080, Caido 8081):
       FoxyProxy toolbar icon -> Options -> Import -> Settings, then pick
       $oniomarchy_share_dir/foxyproxy-oniomarchy.json

    2. Point Caido at port 8081 in its own settings — Burp and Caido BOTH
       default to 8080, so they collide until one moves.

    3. Trust the proxy CA once Burp is running:
       Trigger > Pentest > Trust Proxy CA

    4. Firefox's search-engine list order is not settable by policy — only
       the default is. DuckDuckGo is the default; drag Google if you care.
EOF
