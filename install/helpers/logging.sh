# run_step — run one non-app leaf, with its output going to the log and
# its progress to the live line. See notes/install-ui.md.
#
# Signature is unchanged (`run_step <path-to-script>`), so the seven
# category all.sh files did not have to be touched. The human-readable
# name comes from the table below rather than from a second argument, for
# the same reason.

# Display names for the 13 non-app steps. A path not listed here falls
# back to a name derived from the path, so a new leaf is never nameless —
# but an entry here reads better and costs one line.
declare -A ONIOMARCHY_STEP_LABELS=(
  [preflight/require-omarchy.sh]="Preflight"
  [security/install-scripts.sh]="Security · helper scripts"
  [security/verify-binaries.sh]="Security · discover binaries"
  [security/install-webapps.sh]="Security · web apps"
  [security/menu.sh]="Security menu"
  [services/verify-units.sh]="Services · verify units"
  [services/install-scripts.sh]="Services · helper scripts"
  [services/menu.sh]="Services menu"
  [widgets/tormarchy.sh]="Widget · tormarchy"
  [widgets/macarchy.sh]="Widget · macarchy"
  [trigger/menu.sh]="Trigger menu"
  [themes/install.sh]="Theme wallpapers"
  [themes/branding.sh]="Theme branding"
)

oniomarchy_step_label() {
  local rel="$1"
  if [[ -n ${ONIOMARCHY_STEP_LABELS[$rel]:-} ]]; then
    printf '%s' "${ONIOMARCHY_STEP_LABELS[$rel]}"
    return
  fi
  # Fallback: security/verify-units.sh -> "Security · verify units"
  local dir="${rel%%/*}" base="${rel##*/}"
  base="${base%.sh}"
  printf '%s · %s' "${dir^}" "${base//-/ }"
}

run_step() {
  local script="$1"
  local rel="${script#"$ONIOMARCHY_INSTALL"/}"
  local label
  label="$(oniomarchy_step_label "$rel")"
  local exit_code errexit_was_set=0

  ui_step_start "$label"

  case $- in
    *e*)
      errexit_was_set=1
      set +e
      ;;
  esac

  ui_exec bash -eE -c 'source "$1"' bash "$script"
  exit_code=$?

  local from_line elapsed
  from_line="$(ui_step_log_line)"
  elapsed="$(ui_step_elapsed)"

  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    ui_result ok "$label" "" "$elapsed"
  else
    ui_result fail "$label" "exit $exit_code" "$elapsed"
    ui_fail_excerpt "$from_line" "$exit_code"
    # Read by install.sh's EXIT trap: `set -e` unwinds the whole run from
    # here, so this is the only place that still knows what failed.
    ONIOMARCHY_FAILED_STEP="$label"
  fi

  return $exit_code
}
