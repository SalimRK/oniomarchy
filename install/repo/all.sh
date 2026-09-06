# The binary repository has to exist before anything is installed, so
# this category is sourced by install.sh ahead of apps/all.sh — and after
# the sudo priming, since strap.sh needs root.
#
# Unlike apps/, a failure here is fatal. See repo/enable.sh for why.
run_step "$ONIOMARCHY_INSTALL/repo/enable.sh"
