# Terminal presentation for install.sh — the banner, the one live line
# that redraws in place, the permanent result lines above it, failure
# excerpts, and the closing summary.
#
# Design and rationale: notes/install-ui.md. Two rules from that doc are
# load-bearing and must not be "simplified" away:
#
#   1. The glyph carries the meaning; colour only reinforces it. Three of
#      Omarchy's own 22 themes (vantablack, white, hackerman) define
#      `red` and `green` as the same colour to the eye, so a ✔/✘ told
#      apart only by colour is unreadable on them.
#   2. Colour comes from the theme, never from a hardcoded palette. The
#      terminal's ANSI slots already ARE the theme's colours (every
#      terminal Omarchy ships imports
#      ~/.local/state/omarchy/current/theme/<term>.conf), and `accent` —
#      the one colour with no fixed ANSI slot — is read from that theme's
#      colors.toml.

# --- capability detection -------------------------------------------------

# Can we draw a live line? Needs a real terminal we own. A piped or
# redirected run must not emit cursor-control escapes: that is exactly
# how a tester captures a run (`./install.sh | tee run.log`), and the
# escapes would make the capture unreadable.
ui_can_draw() {
  [[ -t 1 ]] || return 1
  [[ -n ${TERM:-} && $TERM != dumb ]] || return 1
  (( $(_ui_cols) >= 60 )) || return 1
  return 0
}

# Ask the controlling terminal directly. `tput cols` asks ncurses, which
# hunts for a tty among stdin/stdout/stderr — and inside a command
# substitution stdout is a pipe, so if stderr is redirected too it finds
# nothing and silently answers with terminfo's default 80. That is not an
# error you can detect: it just reports the wrong width forever. Measured
# in a resized pty: `tput cols 2>/dev/null` said 80 while the terminal was
# 117 and then 63; `stty size < /dev/tty` said 117 and 63.
_ui_cols() {
  local sz c=""
  if sz=$(stty size 2>/dev/null < /dev/tty); then
    c="${sz##* }"
  fi
  if [[ ! $c =~ ^[0-9]+$ ]]; then
    c="$(tput cols 2>/dev/null)"
  fi
  [[ $c =~ ^[0-9]+$ ]] && (( c > 0 )) || c=80
  printf '%s' "$c"
}

_ui_utf8() {
  [[ ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} == *[Uu][Tt][Ff]* ]]
}

# --- colour ---------------------------------------------------------------

# Read a colour out of the live theme. `current/theme` is the symlink
# omarchy-theme-set maintains; install/themes/install.sh already reads
# this same file for the wallpaper recipe.
#
# Read at run time, on purpose. Omarchy also exports these colours as gum
# env vars (BORDER_FOREGROUND, FOREGROUND, …) from
# /usr/share/omarchy/default/themed/gum_env.lua.tpl — but that file is
# loaded by hypr/envs.lua *at login*, so a shell that was open when the
# user ran `omarchy theme set` still holds the previous theme's colours
# and every gum box drawn from it comes out the old colour. Reading
# colors.toml ourselves and passing the values explicitly is what makes
# this follow a theme change in an already-running terminal.
_ui_theme_hex() {
  local toml="$HOME/.local/state/omarchy/current/theme/colors.toml"
  [[ -r $toml ]] || return 1
  local hex
  hex=$(sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"#?([0-9a-fA-F]{6})\".*/\\1/p" "$toml" | head -1)
  [[ -n $hex ]] || return 1
  printf '%s' "$hex"
}

_ui_hex_to_rgb() { printf '%d;%d;%d' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }

ui_init() {
  UI_LIVE=0
  ui_can_draw && UI_LIVE=1

  # Glyphs first — they are the signal, so they get the safest fallback.
  if _ui_utf8; then
    UI_OK_GLYPH="✔" UI_FAIL_GLYPH="✘" UI_SKIP_GLYPH="·"
    UI_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    UI_RULE="─"
  else
    UI_OK_GLYPH="+" UI_FAIL_GLYPH="!" UI_SKIP_GLYPH="."
    UI_FRAMES=('|' '/' '-' '\')
    UI_RULE="-"
  fi

  C_RESET="" C_DIM="" C_OK="" C_FAIL="" C_ACCENT="" C_BOLD=""
  if [[ -t 1 && -n ${TERM:-} && $TERM != dumb ]] && (( $(tput colors 2>/dev/null || echo 0) >= 8 )); then
    C_RESET=$(tput sgr0)
    C_BOLD=$(tput bold)
    C_DIM=$(tput setaf 8 2>/dev/null || tput dim)
    C_OK=$(tput setaf 2)
    C_FAIL=$(tput setaf 1)

    if [[ ${COLORTERM:-} == *truecolor* || ${COLORTERM:-} == *24bit* ]] && \
       UI_ACCENT_HEX=$(_ui_theme_hex accent); then
      C_ACCENT=$'\e['"38;2;$(_ui_hex_to_rgb "$UI_ACCENT_HEX")m"
      UI_FG_HEX=$(_ui_theme_hex foreground) || UI_FG_HEX=""
    else
      C_ACCENT=$(tput setaf 4)
      UI_ACCENT_HEX="" UI_FG_HEX=""
    fi
  fi

  UI_COLS=$(_ui_cols)
  _ui_layout
  # Deliberately NO `trap ... WINCH` in this shell. With a trap installed,
  # a resize interrupts whatever builtin is running and that builtin
  # returns non-zero — under install.sh's `set -e` that aborts the entire
  # install. Seen for real: resizing the terminal mid-run ended the run at
  # a category boundary with a spurious "Install stopped at" box. The
  # width is re-measured at each step and each result line instead, which
  # costs one `stty` per line and cannot take the run down with it.

  # Without this the terminal echoes "^C" at the cursor when the operator
  # interrupts, which lands in the middle of the live line and survives
  # the redraw as a stray caret. Restored by ui_cleanup.
  _UI_STTY_SAVED=""
  if (( UI_LIVE )) && [[ -t 0 ]]; then
    _UI_STTY_SAVED="$(stty -g 2>/dev/null)" && stty -echoctl 2>/dev/null || _UI_STTY_SAVED=""
  fi

  _ui_spinner_pid=""
  _ui_progress_done=0
  _ui_progress_total=0
}

# --- primitives -----------------------------------------------------------

_ui_hide_cursor() { (( UI_LIVE )) && tput civis 2>/dev/null || true; }
_ui_show_cursor() { (( UI_LIVE )) && tput cnorm 2>/dev/null || true; }

# Clear whatever the live line last drew. Every permanent line goes
# through here first, so output never lands on top of the spinner.
# ESC[J clears from the cursor to the end of the screen. The live region
# is two rows once a step runs long enough to show its output, so clearing
# only the current line would leave the tail row orphaned above the next
# permanent line.
_ui_clear_live() {
  (( UI_LIVE )) && printf '\r\033[J'
  return 0
}

ui_cleanup() {
  _ui_spinner_stop
  _ui_show_cursor
  [[ -n ${_UI_STTY_SAVED:-} ]] && stty "$_UI_STTY_SAVED" 2>/dev/null
  return 0
}

# Seconds -> "48s" / "1m 02s" / "1h 03m".
ui_duration() {
  local s=$1
  if (( s < 60 )); then
    printf '%ds' "$s"
  elif (( s < 3600 )); then
    printf '%dm %02ds' $(( s / 60 )) $(( s % 60 ))
  else
    printf '%dh %02dm' $(( s / 3600 )) $(( s % 3600 / 60 ))
  fi
}

# Bash's printf counts field widths in BYTES, so "%-42s" on a label
# containing "·" (2 bytes, 1 column) pads one short and the whole row
# shifts. ${#s} counts characters in a UTF-8 locale, so pad by hand.
_ui_pad_right() {
  local s="$1" w="$2" n=$(( $2 - ${#1} ))
  (( n > 0 )) && printf -v s '%s%*s' "$s" "$n" ''
  printf '%s' "$s"
}

_ui_pad_left() {
  local s="$1" n=$(( $2 - ${#1} ))
  (( n > 0 )) && printf -v s '%*s%s' "$n" '' "$s"
  printf '%s' "$s"
}

_ui_trunc() {
  local s="$1" w="$2"
  (( ${#s} > w )) && s="${s:0:$(( w - 1 ))}…"
  printf '%s' "$s"
}

# Every field on the live line is a fixed width, so the bar and the
# counter stay in the same columns as the app name underneath the spinner
# changes length. Without this they slide left and right on every app,
# which reads as flicker rather than progress.
# Called before drawing anything permanent. Cheap enough (~180 times in a
# full run) and immune to the errexit problem a signal trap has.
_ui_refresh_cols() {
  local c
  c="$(_ui_cols)"
  if [[ $c != "$UI_COLS" ]]; then
    UI_COLS="$c"
    _ui_layout
  fi
  return 0
}

_ui_layout() {
  : "${_UI_LIVE_CW:=5}"                           # widened to fit the real
                                                  # total by ui_progress_set
  local right=$(( 10 + 1 + _UI_LIVE_CW + 2 + 8 )) # bar, counter, elapsed
  local avail=$(( UI_COLS - 5 - right - 1 ))      # 5 = "  x  " spinner gutter
  local lw=42
  (( avail - lw - 1 < 10 )) && lw=$(( avail * 55 / 100 ))
  (( lw > 42 )) && lw=42
  (( lw < 12 )) && lw=12
  local dw=$(( avail - lw - 1 ))
  (( dw < 4 )) && dw=4
  _UI_LIVE_LW=$lw
  _UI_LIVE_DW=$dw
}

ui_tilde() { printf '%s' "${1/#$HOME/\~}"; }

# --- banner and notes -----------------------------------------------------

# gum reads BORDER_FOREGROUND/FOREGROUND from the environment, which
# Omarchy sets at login and therefore goes stale the moment the user
# switches theme in an open terminal. Passing them explicitly from the
# theme we just read is what keeps the boxes matching the *current*
# theme. Unquoted on purpose at the call sites — this expands to nothing
# when the theme could not be read, leaving gum's own defaults.
_ui_gum_colours() {
  [[ -n ${UI_ACCENT_HEX:-} ]] && printf -- '--border-foreground #%s ' "$UI_ACCENT_HEX"
  [[ -n ${UI_FG_HEX:-} ]] && printf -- '--foreground #%s ' "$UI_FG_HEX"
  return 0
}

# Draw a bordered box whose contents are coloured. gum can draw the box
# but applies one --foreground to everything inside it, which would
# flatten the accent mask into the same colour as the text — so the box
# is drawn here from two parallel arrays: _ui_box_plain holds the text
# without escapes (for measuring), _ui_box_styled holds what is printed.
_ui_box() {
  local inner=0 i
  for i in "${!_ui_box_plain[@]}"; do
    (( ${#_ui_box_plain[i]} > inner )) && inner=${#_ui_box_plain[i]}
  done
  (( inner > UI_COLS - 8 )) && inner=$(( UI_COLS - 8 ))

  local rule=""
  for (( i = 0; i < inner + 2; i++ )); do rule+="─"; done

  printf '\n%s┌%s┐%s\n' "$C_ACCENT" "$rule" "$C_RESET"
  for i in "${!_ui_box_plain[@]}"; do
    printf '%s│%s %s%s %s│%s\n' \
      "$C_ACCENT" "$C_RESET" \
      "${_ui_box_styled[i]}" "$(_ui_pad_right '' $(( inner - ${#_ui_box_plain[i]} )))" \
      "$C_ACCENT" "$C_RESET"
  done
  printf '%s└%s┘%s\n\n' "$C_ACCENT" "$rule" "$C_RESET"
}

ui_banner() {
  _ui_clear_live

  # 27x13, the oni mask at half-block resolution. Byte-identical to the
  # mask in themes/branding/oniomarchy-screensaver.txt (verified), and
  # derived from oniomarchy-about.txt by pairing its rows into ▀/▄/█ —
  # so all three branding assets are the same drawing at three sizes.
  local art_file="${ONIOMARCHY_PATH:-}/themes/branding/oniomarchy-banner.txt"
  local slogan="the hacker's omakase"
  local -a art=()
  if _ui_utf8 && [[ -r $art_file ]] && (( UI_COLS >= 62 )); then
    mapfile -t art < "$art_file"
  fi

  _ui_box_plain=() _ui_box_styled=()
  local i plain styled
  if (( ${#art[@]} > 0 )); then
    for i in "${!art[@]}"; do
      plain="$(_ui_pad_right "${art[i]}" 27)"
      styled="${C_ACCENT}${plain}${C_RESET}"
      case $i in
        5) plain+="    ONIOMARCHY"
           styled+="    ${C_BOLD}${C_ACCENT}ONIOMARCHY${C_RESET}" ;;
        7) plain+="    ${slogan}"
           styled+="    ${C_DIM}${slogan}${C_RESET}" ;;
      esac
      _ui_box_plain+=("$plain")
      _ui_box_styled+=("$styled")
    done
  else
    _ui_box_plain+=("ONIOMARCHY")   _ui_box_styled+=("${C_BOLD}${C_ACCENT}ONIOMARCHY${C_RESET}")
    _ui_box_plain+=("$slogan")      _ui_box_styled+=("${C_DIM}${slogan}${C_RESET}")
  fi

  if [[ -n ${ONIOMARCHY_LOG_SHOWN:-} ]]; then
    plain="log: $(ui_tilde "$ONIOMARCHY_LOG")"
    _ui_box_plain+=("")     _ui_box_styled+=("")
    _ui_box_plain+=("$plain") _ui_box_styled+=("${C_DIM}${plain}${C_RESET}")
  fi

  _ui_box
  _ui_hide_cursor
}

ui_note() {
  _ui_clear_live
  printf '%s  %s%s\n' "$C_DIM" "$1" "$C_RESET"
}

# --- the live line --------------------------------------------------------

ui_progress_set() {
  _ui_progress_done=$1
  _ui_progress_total=$2
  # Size the counter column to the real total once, then leave it alone —
  # including for the later steps that have no count, so the elapsed
  # clock doesn't jump when the run moves from apps to menus.
  if (( $2 > 0 )); then
    local w=$(( 2 * ${#2} + 1 ))
    if (( w != _UI_LIVE_CW )); then
      _UI_LIVE_CW=$w
      _ui_layout
    fi
  fi
}

_ui_bar() {
  local done=$1 total=$2 width=10 filled
  (( total > 0 )) || { printf ''; return; }
  filled=$(( done * width / total ))
  local bar=""
  local i
  for (( i = 0; i < width; i++ )); do
    if (( i < filled )); then bar+="█"; else bar+="░"; fi
  done
  printf '%s' "$bar"
}

# Everything on the live line except the spinner frame and the elapsed
# clock is fixed for the duration of one step, so it is rendered once
# here and handed to the spinner subshell as a single string.
_ui_live_body() {
  local label detail body
  label="$(_ui_pad_right "$(_ui_trunc "$1" "$_UI_LIVE_LW")" "$_UI_LIVE_LW")"
  detail="$(_ui_pad_right "$(_ui_trunc "$2" "$_UI_LIVE_DW")" "$_UI_LIVE_DW")"
  # A third argument marks this as a note (a retry, say) rather than the
  # app name — it gets the accent colour so it reads as a change of state
  # against the dim steady-state line.
  if [[ -n ${3:-} ]]; then
    body="${label} ${C_ACCENT}${detail}${C_RESET}"
  else
    body="${label} ${C_DIM}${detail}${C_RESET}"
  fi

  if (( _ui_progress_total > 0 )); then
    local counter
    counter="$(_ui_pad_left "${_ui_progress_done}/${_ui_progress_total}" "$_UI_LIVE_CW")"
    if _ui_utf8; then
      body+=" ${C_ACCENT}$(_ui_bar "$_ui_progress_done" "$_ui_progress_total")${C_RESET}"
    else
      body+=" $(_ui_pad_right '' 10)"
    fi
    body+=" ${C_DIM}${counter}${C_RESET}"
  else
    # Steps with no progress count still reserve the columns, so the
    # elapsed clock doesn't jump when the run moves from apps to menus.
    body+=" $(_ui_pad_right '' $(( 10 + 1 + _UI_LIVE_CW )))"
  fi
  printf '%s' "$body"
}

# The spinner runs in the background and owns the terminal; the step
# itself runs in the foreground writing only to the log. That separation
# is why this needs no locking — and it avoids the zombie trap of
# backgrounding the work and polling it with `kill -0`, which succeeds
# forever on an unreaped child.
# A step's own process writes to $ONIOMARCHY_STATUS to say something the
# spinner should show — today only pkg.sh's retries. Without it a stalled
# mirror is indistinguishable from a frozen spinner: the retry notice
# goes to the log, and the log is not on screen in quiet mode. That is
# the exact failure this repo restructured around, so it must be visible.
_ui_status_read() {
  [[ -n ${ONIOMARCHY_STATUS:-} && -s ${ONIOMARCHY_STATUS:-} ]] || return 0
  head -c 120 "$ONIOMARCHY_STATUS" 2>/dev/null | tr -d '\n'
}

# After a step has been running a while, show the last line it actually
# printed underneath the spinner. A 72-second step that says only
# "installing hexstrike-ai…" is indistinguishable from a hung one; the
# same step saying "Requirement already satisfied: angr…" is obviously
# working. Read at most twice a second, and only from the log we own.
_UI_TAIL_AFTER=4

_ui_log_tail() {
  [[ -r ${ONIOMARCHY_LOG:-} ]] || return 0
  tail -n 40 "$ONIOMARCHY_LOG" 2>/dev/null \
    | sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\r/ /g' -e 's/\t/ /g' \
    | grep -vE '^###|^[[:space:]]*$' \
    | tail -n 1 \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]\{2,\}/ /g'
}

_ui_spinner_start() {
  (( UI_LIVE )) || return 0
  local label="$1" detail="$2"
  (
    # Not under errexit: this subshell's whole job is to keep drawing, and
    # a printf that returns non-zero because a signal interrupted it must
    # not silently kill the spinner for the rest of the step.
    set +e
    trap 'exit 0' TERM INT
    # The spinner is a separate process, so the parent's WINCH handler
    # cannot reach it: without this it keeps drawing at the old width and
    # every redraw wraps, smearing the line across two rows. It has to
    # re-measure and re-lay-out itself.
    _ui_resized=1
    trap '_ui_resized=1' WINCH
    local start=$SECONDS i=0 n=${#UI_FRAMES[@]}
    local status="" last_status="__unset__" body=""
    local tail_line="" drew_tail=0
    while :; do
      if (( _ui_resized )); then
        UI_COLS=$(_ui_cols)
        _ui_layout
        _ui_resized=0
        last_status="__unset__"   # force a rebuild at the new widths
        # ESC[J clears from the cursor to the end of the screen, taking
        # any row the previous, wider line spilled onto with it.
        printf '\r\033[J'
        drew_tail=0
      fi
      status="$(_ui_status_read)"
      # Rebuilding the body is only worth it when something changed —
      # otherwise this would fork several subshells ten times a second.
      if [[ $status != "$last_status" ]]; then
        if [[ -n $status ]]; then
          body="$(_ui_live_body "$label" "$status" note)"
        else
          body="$(_ui_live_body "$label" "$detail")"
        fi
        last_status="$status"
      fi
      # Refresh the tail at most twice a second — it is a fork, and the
      # spinner ticks ten times a second.
      if (( SECONDS - start >= _UI_TAIL_AFTER )); then
        if (( i % 5 == 0 )); then
          tail_line="$(_ui_log_tail)"
          (( ${#tail_line} > UI_COLS - 8 )) && \
            tail_line="${tail_line:0:$(( UI_COLS - 9 ))}…"
        fi
      else
        tail_line=""
      fi

      printf '\r\033[K  %s%s%s  %s %s%s%s' \
        "$C_ACCENT" "${UI_FRAMES[i % n]}" "$C_RESET" \
        "$body" \
        "$C_DIM" "$(_ui_pad_left "$(ui_duration $(( SECONDS - start )))" 8)" "$C_RESET"

      if [[ -n $tail_line ]]; then
        printf '\n\033[K     %s%s%s\033[A' "$C_DIM" "$tail_line" "$C_RESET"
        drew_tail=1
      elif (( drew_tail )); then
        printf '\n\033[K\033[A'
        drew_tail=0
      fi
      printf '\r'

      i=$(( i + 1 ))
      sleep 0.1
    done
  ) &
  _ui_spinner_pid=$!
}

_ui_spinner_stop() {
  [[ -n ${_ui_spinner_pid:-} ]] || return 0
  kill "$_ui_spinner_pid" 2>/dev/null
  wait "$_ui_spinner_pid" 2>/dev/null
  _ui_spinner_pid=""
  _ui_clear_live
}

# --- steps ----------------------------------------------------------------

_ui_log_lines() {
  [[ -r ${ONIOMARCHY_LOG:-} ]] || { echo 0; return; }
  wc -l < "$ONIOMARCHY_LOG" | tr -d ' '
}

# ui_step_start <label> [detail]
ui_step_start() {
  _ui_step_label="$1"
  _ui_step_detail="${2:-}"
  _ui_step_epoch=$SECONDS

  {
    printf '\n### %s' "$_ui_step_label"
    [[ -n $_ui_step_detail ]] && printf ' · %s' "$_ui_step_detail"
    printf ' · %s\n' "$(date +%H:%M:%S)"
  } >> "$ONIOMARCHY_LOG"

  # After the header, not before: the excerpt should start at the step's
  # own first line of output, not repeat the banner we just wrote.
  _ui_step_mark=$(_ui_log_lines)

  [[ -n ${ONIOMARCHY_STATUS:-} ]] && : > "$ONIOMARCHY_STATUS"
  _ui_refresh_cols

  if (( UI_LIVE )); then
    _ui_spinner_start "$_ui_step_label" "$_ui_step_detail"
  else
    printf '==> %s%s\n' "$_ui_step_label" "${_ui_step_detail:+ · $_ui_step_detail}"
  fi
}

# Line number the current step's output starts at, for the "see line N"
# pointer.
ui_step_log_line() { echo $(( _ui_step_mark + 1 )); }
ui_step_elapsed()  { echo $(( SECONDS - _ui_step_epoch )); }

ui_step_stop_live() { _ui_spinner_stop; }

# ui_result ok|fail <label> <detail> <seconds>
ui_result() {
  local status="$1" label="$2" detail="$3" secs="$4"
  _ui_spinner_stop
  _ui_refresh_cols

  local glyph colour
  if [[ $status == ok ]]; then
    glyph="$UI_OK_GLYPH" colour="$C_OK"
  else
    glyph="$UI_FAIL_GLYPH" colour="$C_FAIL"
  fi

  # Label field shrinks on narrow terminals rather than wrapping.
  local lw=$(( UI_COLS - 30 ))
  (( lw > 42 )) && lw=42
  (( lw < 18 )) && lw=18
  (( ${#label} > lw )) && label="${label:0:$(( lw - 1 ))}…"

  printf '  %s%s%s  %s %s%s  %s%s\n' \
    "$colour" "$glyph" "$C_RESET" \
    "$(_ui_pad_right "$label" "$lw")" \
    "$C_DIM" "$(_ui_pad_left "$detail" 10)" \
    "$(_ui_pad_left "$(ui_duration "$secs")" 8)" "$C_RESET"
}

# Decision (a) from notes/install-ui.md: on failure, drop out of the
# pretty view and show the error here, rather than sending the operator
# off to find a log file.
ui_fail_excerpt() {
  local from_line="$1" exit_code="$2" max=30
  local rule_len=$(( UI_COLS - 8 ))
  (( rule_len > 66 )) && rule_len=66
  (( rule_len < 20 )) && rule_len=20

  local rule=""
  local i
  for (( i = 0; i < rule_len; i++ )); do rule+="$UI_RULE"; done

  printf '     %s%s last %d lines %s%s\n' "$C_DIM" "$UI_RULE$UI_RULE" "$max" "${rule:0:$(( rule_len - 18 ))}" "$C_RESET"
  tail -n "+$from_line" "$ONIOMARCHY_LOG" 2>/dev/null \
    | tail -n "$max" \
    | tr -d '\r' \
    | sed "s/^/     /"
  printf '     %s%s%s\n' "$C_DIM" "$rule" "$C_RESET"
  if [[ -n ${ONIOMARCHY_LOG_SHOWN:-} ]]; then
    printf '     %sfull output: %s line %s%s\n\n' \
      "$C_DIM" "$(ui_tilde "$ONIOMARCHY_LOG")" "$from_line" "$C_RESET"
  else
    printf '\n'
  fi
}

# --- summary --------------------------------------------------------------

ui_summary() {
  local ok="$1" failed="$2" secs="$3" failed_names="$4"
  _ui_spinner_stop
  _ui_show_cursor

  local -a lines
  if (( failed == 0 )); then
    lines=("${UI_OK_GLYPH}  Install complete" "" "$ok apps installed · $(ui_duration "$secs")")
  else
    lines=("${UI_FAIL_GLYPH}  Install finished with failures" "" \
           "$ok installed · $failed failed · $(ui_duration "$secs")" \
           "" "failed: $failed_names" \
           "" "re-run ./install.sh to retry just those —" \
           "anything already installed is skipped")
  fi
  [[ -n ${ONIOMARCHY_PACK_SUMMARY:-} ]] && lines+=("" "packs: $ONIOMARCHY_PACK_SUMMARY")
  [[ -n ${ONIOMARCHY_LOG_SHOWN:-} ]] && lines+=("" "log: $(ui_tilde "$ONIOMARCHY_LOG")")

  if (( UI_LIVE )) && command -v gum >/dev/null 2>&1; then
    gum style --border normal --padding "0 2" --margin "1 0" \
      $(_ui_gum_colours) "${lines[@]}"
  else
    printf '\n'
    local l
    for l in "${lines[@]}"; do printf '  %s\n' "$l"; done
    printf '\n'
  fi
}

# A non-app step failing aborts the run under `set -e` (deliberately —
# see install/apps/all.sh for why only apps are allowed to continue). The
# excerpt is already on screen by then, but without this the run simply
# stops: no closing box, no log path, and nothing saying that the later
# categories never ran.
ui_aborted() {
  local step="$1" code="$2"
  _ui_spinner_stop
  _ui_show_cursor

  local -a lines=(
    "${UI_FAIL_GLYPH}  Install stopped at: ${step:-an install step}"
    ""
    "The steps after it did not run."
    "Fix the error above, then re-run ./install.sh —"
    "anything already installed is skipped."
  )
  [[ -n ${ONIOMARCHY_LOG_SHOWN:-} ]] && lines+=("" "log: $(ui_tilde "$ONIOMARCHY_LOG")")

  if (( UI_LIVE )) && command -v gum >/dev/null 2>&1; then
    gum style --border normal --padding "0 2" --margin "1 0" \
      $(_ui_gum_colours) "${lines[@]}"
  else
    printf '\n'
    local l
    for l in "${lines[@]}"; do printf '  %s\n' "$l"; done
    printf '\n'
  fi
}

ui_interrupted() {
  ONIOMARCHY_UI_INTERRUPTED=1
  _ui_spinner_stop
  _ui_show_cursor
  printf '\n  %s%s  Interrupted.%s\n' "$C_FAIL" "$UI_FAIL_GLYPH" "$C_RESET"
  [[ -n ${ONIOMARCHY_LOG_SHOWN:-} ]] && \
    printf '  %slog: %s%s\n\n' "$C_DIM" "$(ui_tilde "$ONIOMARCHY_LOG")" "$C_RESET"
}

# --- running a step -------------------------------------------------------

# ui_exec <command...> — run a step's command with its output going to
# the log (quiet) or to both log and terminal (verbose). Returns the
# command's own exit code, and never lets errexit abort the caller
# mid-measurement.
ui_exec() {
  local rc errexit_was_set=0
  case $- in *e*) errexit_was_set=1; set +e ;; esac

  if (( ONIOMARCHY_VERBOSE )); then
    "$@" 2>&1 | tee -a "$ONIOMARCHY_LOG"
    rc=${PIPESTATUS[0]}
  else
    # stdin closed on purpose: a step that unexpectedly asks a question
    # must fail fast rather than silently swallow the operator's
    # keystrokes behind a spinner.
    "$@" >> "$ONIOMARCHY_LOG" 2>&1 < /dev/null
    rc=$?
  fi

  (( errexit_was_set )) && set -e
  return "$rc"
}
