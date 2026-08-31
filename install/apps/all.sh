# One application, one script. Every leaf under install/apps/<category>/
# installs exactly one app, plus whatever that app specifically needs —
# dependency fixes, build overrides, shipped config, post-install patches.
# See notes/per-app-scripts.md for the design and the tester log that
# prompted it.
#
# Unlike every other category in this repo, a failing leaf here does NOT
# abort the run. One broken PKGBUILD or one stalled download must not
# cost the other 80 apps — that is exactly what left the first tester
# with zero packages installed after three attempts. Failures are
# collected and reported at the end, and the category still exits
# non-zero so a partial install never reads as a clean one.
#
# Presentation: one permanent line per *category*, not per app (81 lines
# of ✔ would be the same wall of noise this replaced). The live line
# below it names the individual app in flight. A failing app breaks that
# rule on purpose — it prints immediately, with its error, per decision
# (a) in notes/install-ui.md.

ONIOMARCHY_APPS="$ONIOMARCHY_INSTALL/apps"
export ONIOMARCHY_APPS

_oniomarchy_apps_ok=0
_oniomarchy_apps_failed=()

# Directory name -> display name. Title-casing the directory covers 15 of
# the 18; these three don't survive it. Names match the Menu Tree in
# notes/pentest-tools.md and install/security/menu.sh.
declare -A _ONIOMARCHY_CATEGORY_LABELS=(
  [ai-tools]="AI Tools"
  [sdr]="SDR"
  [sniffing-spoofing]="Sniffing & Spoofing"
)

_oniomarchy_category_label() {
  local dir="$1"
  if [[ -n ${_ONIOMARCHY_CATEGORY_LABELS[$dir]:-} ]]; then
    printf '%s' "${_ONIOMARCHY_CATEGORY_LABELS[$dir]}"
    return
  fi
  local words="${dir//-/ }" out="" w
  for w in $words; do out+="${w^} "; done
  printf '%s' "${out% }"
}

# Like helpers/logging.sh's run_step, with two differences: it sources
# lib/pkg.sh into the leaf's own bash first (shell functions don't cross
# a process boundary the way exported variables do, so a plain `source
# "$script"` would leave pkg_official/pkg_aur undefined), and it always
# returns 0 so a failure is recorded rather than propagated.
run_app() {
  local script="$1" category_label="$2"
  local app; app="$(basename "$script" .sh)"
  local exit_code errexit_was_set=0

  ui_step_start "$category_label" "installing $app…"

  case $- in
    *e*)
      errexit_was_set=1
      set +e
      ;;
  esac

  ONIOMARCHY_APP_DIR="$(dirname "$script")" \
    ui_exec bash -eE -c 'source "$1"; source "$2"' bash \
      "$ONIOMARCHY_APPS/lib/pkg.sh" "$script"
  exit_code=$?

  local from_line; from_line="$(ui_step_log_line)"
  local elapsed;  elapsed="$(ui_step_elapsed)"

  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    ui_step_stop_live
    _oniomarchy_apps_ok=$(( _oniomarchy_apps_ok + 1 ))
  else
    ui_result fail "$category_label · $app" "exit $exit_code" "$elapsed"
    ui_fail_excerpt "$from_line" "$exit_code"
    _oniomarchy_apps_failed+=("$app")
  fi

  return 0
}

# Fill the pacman cache once, up front. Its own step because it is the
# single longest thing in the run and must not look like a hang.
run_step_prefetch() {
  local elapsed from_line rc errexit_was_set=0
  ui_step_start "Prefetch official packages"

  case $- in *e*) errexit_was_set=1; set +e ;; esac
  ui_exec bash -eE -c 'source "$1"' bash "$ONIOMARCHY_APPS/lib/prefetch.sh"
  rc=$?
  from_line="$(ui_step_log_line)"
  elapsed="$(ui_step_elapsed)"
  (( errexit_was_set )) && set -e

  # Non-fatal by design (see lib/prefetch.sh) — a stalled mirror here
  # must not stop the run; each app fetches what it needs on its own.
  if (( rc == 0 )); then
    ui_result ok "Prefetch official packages" "" "$elapsed"
  else
    ui_result fail "Prefetch official packages" "incomplete" "$elapsed"
    ui_fail_excerpt "$from_line" "$rc"
    ui_note "Prefetch is non-fatal — each app will fetch what it needs."
  fi
  return 0
}

run_step_prefetch

# Leaves are discovered, not listed — adding a tool is dropping in one
# file. `files/` holds payloads an app installs (unit files, wrapper
# scripts); those are never executed as leaves. lib/ is excluded for the
# same reason.
mapfile -t _oniomarchy_app_list < <(
  find "$ONIOMARCHY_APPS" -mindepth 2 -name '*.sh' \
    -not -path "$ONIOMARCHY_APPS/lib/*" \
    -not -path '*/files/*' | sort
)

_oniomarchy_apps_total=${#_oniomarchy_app_list[@]}
_oniomarchy_apps_seen=0

# Category boundaries are visible in the sorted list, so the per-category
# result line is emitted when the directory changes — no second pass and
# no manifest.
_oniomarchy_cat_dir=""
_oniomarchy_cat_label=""
_oniomarchy_cat_start=0
_oniomarchy_cat_ok=0
_oniomarchy_cat_failed=0

_oniomarchy_close_category() {
  [[ -n $_oniomarchy_cat_dir ]] || return 0
  local n=$(( _oniomarchy_cat_ok + _oniomarchy_cat_failed ))
  local elapsed=$(( SECONDS - _oniomarchy_cat_start ))
  local noun="apps"; (( n == 1 )) && noun="app"
  if (( _oniomarchy_cat_failed == 0 )); then
    ui_result ok "$_oniomarchy_cat_label" "$n $noun" "$elapsed"
  else
    ui_result fail "$_oniomarchy_cat_label" "$_oniomarchy_cat_ok/$n $noun" "$elapsed"
  fi
}

for _oniomarchy_app in "${_oniomarchy_app_list[@]}"; do
  _oniomarchy_dir="$(basename "$(dirname "$_oniomarchy_app")")"

  if [[ $_oniomarchy_dir != "$_oniomarchy_cat_dir" ]]; then
    _oniomarchy_close_category
    _oniomarchy_cat_dir="$_oniomarchy_dir"
    _oniomarchy_cat_label="$(_oniomarchy_category_label "$_oniomarchy_dir")"
    _oniomarchy_cat_start=$SECONDS
    _oniomarchy_cat_ok=0
    _oniomarchy_cat_failed=0
  fi

  ui_progress_set "$_oniomarchy_apps_seen" "$_oniomarchy_apps_total"

  _oniomarchy_before_ok=$_oniomarchy_apps_ok
  run_app "$_oniomarchy_app" "$_oniomarchy_cat_label"
  if (( _oniomarchy_apps_ok > _oniomarchy_before_ok )); then
    _oniomarchy_cat_ok=$(( _oniomarchy_cat_ok + 1 ))
  else
    _oniomarchy_cat_failed=$(( _oniomarchy_cat_failed + 1 ))
  fi

  _oniomarchy_apps_seen=$(( _oniomarchy_apps_seen + 1 ))
done
_oniomarchy_close_category
ui_progress_set 0 0

unset _oniomarchy_app _oniomarchy_dir _oniomarchy_before_ok

# Reported by install.sh at the very end, not raised here. Failing the
# category now would abort install.sh's `set -e` and skip the security
# menu, services, widgets and themes — which is the same all-or-nothing
# trap at a larger scale. The run finishes; the exit code still tells
# the truth.
ONIOMARCHY_APPS_OK=$_oniomarchy_apps_ok
ONIOMARCHY_APPS_TOTAL=$_oniomarchy_apps_total
export ONIOMARCHY_APPS_OK ONIOMARCHY_APPS_TOTAL
if (( ${#_oniomarchy_apps_failed[@]} > 0 )); then
  ONIOMARCHY_APPS_FAILED="${_oniomarchy_apps_failed[*]}"
  export ONIOMARCHY_APPS_FAILED
fi
