echo "==> Installing Oniomarchy theme backgrounds (wordmarks + lockups)"

# Adds our recolored "ONIOMARCHY" wordmark as an extra selectable
# wallpaper for each stock Omarchy theme, via Omarchy's real per-theme
# background override directory: `~/.config/omarchy/backgrounds/<theme>/`.
#
# This corrects a wrong first attempt (2026-08-28, same session): the
# stock "OMARCHY" wordmark isn't a standalone branding file at a theme's
# root — `find /usr/share/omarchy/themes/<name>` shows it's
# `<name>/backgrounds/omarchy.png`, one of the theme's *rotating
# wallpapers*, nested inside backgrounds/. An earlier version of this
# script wrote to `~/.config/omarchy/themes/<name>/omarchy.png` (theme
# root) assuming that was a logo file with some UI consumer — grepping
# the whole shell/bin tree found none (not the theme switcher, which only
# reads preview.png/first-background; not the lock screen, which reuses
# whatever the current wallpaper already is; not SDDM/Plymouth, which use
# a single fixed system-wide logo.png, not per-theme). That file was a
# harmless but useless decoy at the wrong directory level and has been
# removed.
#
# The real mechanism, read from `choose_theme_background()` in
# /usr/share/omarchy/bin/omarchy-theme-set (not guessed): it pools
# candidate wallpapers from `~/.config/omarchy/backgrounds/$THEME_NAME/`
# *and* `$CURRENT_THEME_PATH/backgrounds/` together, and cycles through
# whichever pool is non-empty. Confirmed live by reproducing that exact
# `find` command against this machine's real vantablack theme: a wordmark
# dropped into `~/.config/omarchy/backgrounds/vantablack/` shows up in
# the same candidate list as the theme's own 0-dot-hands.jpg etc.
# Additive, not a replacement — the theme's own default wallpapers (and
# its own stock omarchy.png background) stay in the rotation too.
#
# Source assets live in themes/wordmarks/ and themes/lockups/ at the repo
# root (not notes/theme-backgrounds/, which is gitignored/untracked — see
# notes/theme-background-plan.md) so a fresh clone of this repo can
# actually run this script. Filenames were confirmed to match
# /usr/share/omarchy/themes/*'s real directory names exactly, 1:1, no
# guessing.
#
# TWO sets are installed, and they must not collide: both land in the
# same ~/.config/omarchy/backgrounds/<theme>/ folder, so the theme name
# cannot simply be "whatever follows oniomarchy-".
#
#   themes/wordmarks/oniomarchy-<theme>.png         the wordmark alone
#   themes/lockups/oniomarchy-lockup-<theme>.png    oni mask over wordmark
#
# Hence the explicit prefix argument below rather than a single fixed
# strip: `oniomarchy-lockup-catppuccin.png` must yield `catppuccin`, and
# stripping only `oniomarchy-` would yield `lockup-catppuccin`, which
# matches no stock theme and would be skipped by the guard — silently
# installing nothing.
#
# The oni-reimagined *scenic* backgrounds (a separate, still-unfinished
# asset — see notes/theme-background-plan.md) are NOT installed by this
# step; they're still pending an external 4K regen, and will land the
# same way once they exist.

# _oniomarchy_install_backgrounds <src_dir> <filename_prefix> <label>
#
# Copies every <prefix><theme>.png into that theme's background override
# folder. A file naming a theme this machine does not have is skipped
# rather than guessed at.
_oniomarchy_install_backgrounds() {
  local src_dir="$1" prefix="$2" label="$3"
  local file theme count=0

  if [[ ! -d $src_dir ]]; then
    echo "==> [themes/install] missing asset dir: $src_dir" >&2
    return 1
  fi

  for file in "$src_dir/$prefix"*.png; do
    [[ -f $file ]] || continue
    theme=$(basename "$file" .png)
    theme=${theme#"$prefix"}

    if [[ ! -d /usr/share/omarchy/themes/$theme ]]; then
      echo "==> [themes/install] $theme: no such stock Omarchy theme — skipping (no guessing)" >&2
      continue
    fi

    mkdir -p "$HOME/.config/omarchy/backgrounds/$theme"
    cp "$file" "$HOME/.config/omarchy/backgrounds/$theme/"
    count=$((count + 1))
  done

  echo "==> Installed $count oniomarchy $label to ~/.config/omarchy/backgrounds/<theme>/"
}

_oniomarchy_install_backgrounds "$ONIOMARCHY_PATH/themes/wordmarks" oniomarchy- wordmarks
_oniomarchy_install_backgrounds "$ONIOMARCHY_PATH/themes/lockups" oniomarchy-lockup- lockups

echo "==> Cycle backgrounds (theme picker / next-wallpaper action) on the current theme to see them"
echo "==> Oni-reimagined scenic backgrounds not installed yet — regen in progress, see notes/theme-background-plan.md"

unset -f _oniomarchy_install_backgrounds
