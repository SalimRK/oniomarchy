# Shared hand-rolled JSON string escaping for CLI --json output.
# Backslash and double-quote only — matches the same minimal escaper every
# JSONC-emitting script in this repo already uses (oniomarchy_jesc in
# trigger/menu.sh, security/menu.sh, services/menu.sh). No `jq` dependency:
# see notes/oniomarchy-cli.md's "--json schema" section for why.
oniomarchy_json_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}
