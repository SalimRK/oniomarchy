run_step() {
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

  bash -eE -c 'source "$1"' bash "$script"
  exit_code=$?

  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    echo "==> Done: $label"
  else
    echo "==> FAILED: $label (exit code: $exit_code)" >&2
  fi

  return $exit_code
}
