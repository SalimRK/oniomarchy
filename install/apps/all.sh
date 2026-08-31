# One application, one script. Every leaf under install/apps/<category>/
# installs exactly one app, plus whatever that app specifically needs —
# dependency fixes, build overrides, shipped config, post-install patches.
# See notes/per-app-scripts.md for the design and the tester log that
# prompted it.
#
# Unlike every other category in this repo, a failing leaf here does NOT
# abort the run. One broken PKGBUILD or one stalled download must not
# cost the other 78 apps — that is exactly what left the first tester
# with zero packages installed after three attempts. Failures are
# collected and reported at the end, and the category still exits
# non-zero so a partial install never reads as a clean one.

ONIOMARCHY_APPS="$ONIOMARCHY_INSTALL/apps"
export ONIOMARCHY_APPS

source "$ONIOMARCHY_APPS/lib/prefetch.sh"

_oniomarchy_apps_ok=0
_oniomarchy_apps_failed=()

# Like helpers/logging.sh's run_step, with two differences: it sources
# lib/pkg.sh into the leaf's own bash first (shell functions don't cross
# a process boundary the way exported variables do, so a plain `source
# "$script"` would leave pkg_official/pkg_aur undefined), and it always
# returns 0 so a failure is recorded rather than propagated.
run_app() {
  local script="$1"
  local label="${script#"$ONIOMARCHY_INSTALL"/}"
  local exit_code errexit_was_set=0

  echo "==> Running: $label"

  case $- in
    *e*)
      errexit_was_set=1
      set +e
      ;;
  esac

  ONIOMARCHY_APP_DIR="$(dirname "$script")" \
    bash -eE -c 'source "$1"; source "$2"' bash "$ONIOMARCHY_APPS/lib/pkg.sh" "$script"
  exit_code=$?

  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    echo "==> Done: $label"
    _oniomarchy_apps_ok=$(( _oniomarchy_apps_ok + 1 ))
  else
    echo "==> FAILED: $label (exit code: $exit_code)" >&2
    _oniomarchy_apps_failed+=("$(basename "$script" .sh)")
  fi

  return 0
}

# Leaves are discovered, not listed — adding a tool is dropping in one
# file. `files/` holds payloads an app installs (unit files, wrapper
# scripts); those are never executed as leaves. lib/ is excluded for the
# same reason.
while IFS= read -r _oniomarchy_app; do
  run_app "$_oniomarchy_app"
done < <(
  find "$ONIOMARCHY_APPS" -mindepth 2 -name '*.sh' \
    -not -path "$ONIOMARCHY_APPS/lib/*" \
    -not -path '*/files/*' | sort
)
unset _oniomarchy_app

_oniomarchy_apps_total=$(( _oniomarchy_apps_ok + ${#_oniomarchy_apps_failed[@]} ))
echo "==> $_oniomarchy_apps_ok of $_oniomarchy_apps_total apps installed"

# Reported by install.sh at the very end, not raised here. Failing the
# category now would abort install.sh's `set -e` and skip the security
# menu, services, widgets and themes — which is the same all-or-nothing
# trap at a larger scale. The run finishes; the exit code still tells
# the truth.
if (( ${#_oniomarchy_apps_failed[@]} > 0 )); then
  echo "==> Failed: ${_oniomarchy_apps_failed[*]}" >&2
  ONIOMARCHY_APPS_FAILED="${_oniomarchy_apps_failed[*]}"
  export ONIOMARCHY_APPS_FAILED
fi
