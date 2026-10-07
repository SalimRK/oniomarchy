echo "==> Installing the Oniomarchy post-update hook"

# Through Omarchy's own CLI, never by writing into its directories by
# hand. `omarchy hook install` copies the file into
# ~/.config/omarchy/hooks/post-update.d/ — user config, untouched by
# `omarchy update` — and overwrites it on rerun, so the installed hook
# always matches this checkout.
omarchy hook install post-update "$ONIOMARCHY_INSTALL/hooks/oniomarchy-update.hook"
