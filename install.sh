#!/usr/bin/env bash
#
# Oniomarchy Phase 1 installer — overlay on top of a stock Omarchy system.
# See notes/ROADMAP.md (Phase 1 scope), notes/pentest-tools.md (tool/menu/
# services plan), and notes/install-layout.md (this script's own layout,
# adapted from Omarchy's real install/ structure — notes/omarchy-script-structure.md).
#
# Does everything the Omarchy way: `omarchy pkg add`, `omarchy hook install`,
# ~/.config/omarchy/extensions/omarchy-menu.jsonc — never touches
# /usr/share/omarchy/ (package-owned, wiped on `omarchy update`).

set -euo pipefail

ONIOMARCHY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ONIOMARCHY_PATH
export ONIOMARCHY_INSTALL="$ONIOMARCHY_PATH/install"

source "$ONIOMARCHY_INSTALL/helpers/logging.sh"

source "$ONIOMARCHY_INSTALL/preflight/all.sh"
source "$ONIOMARCHY_INSTALL/packages/all.sh"
source "$ONIOMARCHY_INSTALL/security/all.sh"
source "$ONIOMARCHY_INSTALL/services/all.sh"
source "$ONIOMARCHY_INSTALL/hooks/all.sh"
source "$ONIOMARCHY_INSTALL/widgets/all.sh"
source "$ONIOMARCHY_INSTALL/trigger/all.sh"
source "$ONIOMARCHY_INSTALL/themes/all.sh"

echo "==> Oniomarchy Phase 1 install complete."
echo "==> Working: preflight, package install, security menu, trigger menu, services menu, widgets, theme wordmarks."
echo "==> Hooks: none needed, by design (see CLAUDE.md Architecture)."
echo "==> Pending: oni-reimagined theme backgrounds (external regen in progress, see notes/theme-background-plan.md)."
