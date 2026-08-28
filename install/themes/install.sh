echo "==> Installing Oniomarchy theme wordmarks"

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
# Source assets live in themes/wordmarks/ at the repo root (not
# notes/theme-backgrounds/, which is gitignored/untracked — see
# notes/theme-background-plan.md) so a fresh clone of this repo can
# actually run this script. Filenames (oniomarchy-<theme>.png) were
# confirmed to match /usr/share/omarchy/themes/*'s real directory names
# exactly, 1:1, no guessing.
#
# The oni-reimagined *scenic* backgrounds (a separate, still-unfinished
# asset — see notes/theme-background-plan.md) are NOT installed by this
# step; they're still pending an external 4K regen, and will land the
# same way once they exist.

_oniomarchy_wordmarks_dir="$ONIOMARCHY_PATH/themes/wordmarks"
_oniomarchy_backgrounds_dir="$HOME/.config/omarchy/backgrounds"
_oniomarchy_wordmark_count=0

for _oniomarchy_wordmark in "$_oniomarchy_wordmarks_dir"/oniomarchy-*.png; do
  [[ -f $_oniomarchy_wordmark ]] || continue
  _oniomarchy_theme=$(basename "$_oniomarchy_wordmark" .png)
  _oniomarchy_theme=${_oniomarchy_theme#oniomarchy-}

  if [[ ! -d /usr/share/omarchy/themes/$_oniomarchy_theme ]]; then
    echo "==> [themes/install] $_oniomarchy_theme: no such stock Omarchy theme — skipping (no guessing)" >&2
    continue
  fi

  mkdir -p "$_oniomarchy_backgrounds_dir/$_oniomarchy_theme"
  cp "$_oniomarchy_wordmark" "$_oniomarchy_backgrounds_dir/$_oniomarchy_theme/"
  _oniomarchy_wordmark_count=$((_oniomarchy_wordmark_count + 1))
done

echo "==> Installed $_oniomarchy_wordmark_count oniomarchy wordmarks to $_oniomarchy_backgrounds_dir/<theme>/"
echo "==> Cycle backgrounds (theme picker / next-wallpaper action) on the current theme to see it"
echo "==> Oni-reimagined scenic backgrounds not installed yet — regen in progress, see notes/theme-background-plan.md"

unset _oniomarchy_wordmarks_dir _oniomarchy_backgrounds_dir _oniomarchy_wordmark_count _oniomarchy_wordmark _oniomarchy_theme
