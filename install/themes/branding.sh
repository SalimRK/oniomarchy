echo "==> Installing Oniomarchy branding (oni mask + ONIOMARCHY wordmark)"

# Replaces both of Omarchy's ASCII branding slots with oniomarchy art
# drawn in the same visual language as the stock originals — the same
# three block glyphs (U+2588 full, U+2580/U+2584 half), the same grid,
# nothing new introduced.
#
# Both target paths, their packaged defaults, and the canonical About
# size were read from Omarchy's own branding API, not guessed:
#   - /usr/share/omarchy/bin/omarchy-branding-about edits
#     ~/.config/omarchy/branding/about.txt, resets it from
#     $OMARCHY_PATH/icon.txt, and its `image` mode transcodes to
#     `--width 54 --height 26` — that's the canonical About frame.
#     /etc/fastfetch/config.jsonc reads that same file as its logo.
#   - /usr/share/omarchy/bin/omarchy-branding-screensaver edits
#     ~/.config/omarchy/branding/screensaver.txt and resets it from
#     $OMARCHY_PATH/logo.txt (the stock ASCII OMARCHY wordmark).
#     /usr/share/omarchy/bin/omarchy-screensaver feeds that file to
#     `ttfx ... --canvas-width 0 --canvas-height 0 --anchor-canvas c`,
#     i.e. it's centered on a full-screen terminal at font-size 18, so
#     there's no fixed size — only whatever the display gives you.
#     Measured for real on this machine rather than guessed: kitty at
#     font_size=18 (what omarchy-launch-screensaver hardcodes) gives a
#     14x32 logical-px cell, so a 1920x1080 @1.25 monitor is 109x27
#     cells and 1920x1200 @1.25 is 109x30. Ours is 108x25 and the stock
#     one is 81x10. 109x27 — the tighter of the two — is the ceiling the
#     guard below enforces.
#
#     That ceiling is a lint on the ASSET, not a check of the running
#     display: it catches art that was regenerated too large, but a
#     smaller screen than any measured here would still clip. Nothing
#     can be done about that at install time anyway, since the art is
#     fixed at build time and the font size is not adjustable.
#
#     Note that blank rows/columns in the file CANNOT be used to make
#     the art sit smaller: ttfx centers the block on a canvas the size
#     of the terminal, so padding only makes the block bigger. Fitting
#     is purely a matter of using fewer cells, and there is no font-size
#     knob to turn — the launcher hardcodes it. Earlier 108x33 and
#     108x46 versions of this lockup overflowed both monitors and were
#     clipped top and bottom.
#
#     The way it now fits is the same trick stock logo.txt uses and this
#     art originally did not: the half-block glyphs U+2580/U+2584 give
#     two sub-rows per terminal row, so the wordmark occupies 10 rows
#     instead of 19 at identical on-screen size. See
#     notes/theme-backgrounds/reference/make-lockup.py, which renders
#     this file and is the only thing that should edit it.
#
#     If this is ever regenerated from a PNG via `omarchy transcode
#     ascii` instead of hand-drawn, --invert is REQUIRED: the
#     transcoder treats *dark* pixels as the logo, and our art is a
#     light mark on a dark background, so without it the polarity comes
#     out backwards — a solid field with the oni face punched out.
#     It would also come back as full-block-only art, losing the
#     half-block resolution the fit depends on.
#
# Because both slots have a packaged `reset` mode, the undo path is
# Omarchy's own (`omarchy branding about reset` /
# `omarchy branding screensaver reset`) and no backup files are written.
#
# What IS written is a stamp — a copy of exactly what this script last
# installed, under ~/.local/share/oniomarchy/branding/. It exists to
# answer one question the art itself can't: "is the file currently in
# place an older version of ours, or something the user drew?" Both look
# equally unlike the current asset and equally unlike the stock default,
# so without the stamp the customization guard below blocks our own
# updates (found the hard way — a resized screensaver refused to
# install over its own predecessor). The files must stay pure art for
# ttfx/fastfetch to render them, so an in-file marker isn't an option.
#
# ~/.config/omarchy/branding/ is user config, never package-owned, so
# this respects the "never touch /usr/share/omarchy/" rule.

# _oniomarchy_install_branding <src> <dst> <stock> [exact_dims] [max_dims]
#
# Overwrites the stock art and any version of our own (so reruns and
# asset updates are both idempotent), but never clobbers art the user
# set themselves via `omarchy branding <slot> image|text`.
_oniomarchy_install_branding() {
  local src="$1" dst="$2" stock="$3" exact="${4:-}" max="${5:-}"
  local slot dims stamp w h maxw maxh
  slot=$(basename "$dst" .txt)
  stamp="$HOME/.local/share/oniomarchy/branding/$slot.txt"

  if [[ ! -f $src ]]; then
    echo "==> [themes/branding] missing asset: $src" >&2
    return 1
  fi

  # Verify real dimensions rather than trusting the art to have stayed the
  # size it was drawn at. Both slots fail silently when the art is wrong —
  # fastfetch pads/clips the About frame and misaligns the whole info
  # block, ttfx clips the screensaver against the canvas edges — so this
  # is the only place either mistake can be caught loudly.
  #
  # Counts characters, not bytes, so LC_ALL must not force C here: the art
  # is entirely multi-byte block glyphs and a byte count would read 3x
  # wide. awk's length() is character-based under a UTF-8 locale.
  if [[ -n $exact || -n $max ]]; then
    dims=$(awk '{ if (length($0) > w) w = length($0) } END { print w "x" NR }' "$src")
  fi

  if [[ -n $exact && $dims != "$exact" ]]; then
    echo "==> [themes/branding] $slot asset is $dims, expected exactly $exact — refusing to install" >&2
    return 1
  fi

  if [[ -n $max ]]; then
    w=${dims%x*} h=${dims#*x}
    maxw=${max%x*} maxh=${max#*x}
    if ((w > maxw || h > maxh)); then
      echo "==> [themes/branding] $slot asset is $dims, over the ${max} ceiling — refusing to install" >&2
      echo "==> [themes/branding] it would be clipped; regenerate with notes/theme-backgrounds/reference/make-lockup.py" >&2
      return 1
    fi
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -f $dst ]] &&
    ! cmp -s "$dst" "$src" &&
    ! cmp -s "$dst" "$stock" &&
    ! { [[ -f $stamp ]] && cmp -s "$dst" "$stamp"; }; then
    echo "==> [themes/branding] $dst was customized — leaving it alone"
    echo "==> [themes/branding] to take ours: cp \"$src\" \"$dst\""
    return 0
  fi

  cp "$src" "$dst"
  mkdir -p "$(dirname "$stamp")"
  cp "$src" "$stamp"
  echo "==> Installed $slot branding to $dst"
}

_oniomarchy_branding_src="$ONIOMARCHY_PATH/themes/branding"
_oniomarchy_branding_dst="$HOME/.config/omarchy/branding"

_oniomarchy_install_branding \
  "$_oniomarchy_branding_src/oniomarchy-about.txt" \
  "$_oniomarchy_branding_dst/about.txt" \
  /usr/share/omarchy/icon.txt \
  54x26

_oniomarchy_install_branding \
  "$_oniomarchy_branding_src/oniomarchy-screensaver.txt" \
  "$_oniomarchy_branding_dst/screensaver.txt" \
  /usr/share/omarchy/logo.txt \
  "" 109x27

echo "==> See them: omarchy about  /  omarchy screensaver"
echo "==> Undo: omarchy branding about reset  /  omarchy branding screensaver reset"

unset -f _oniomarchy_install_branding
unset _oniomarchy_branding_src _oniomarchy_branding_dst
