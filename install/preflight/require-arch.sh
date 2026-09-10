# [oniomarchy] publishes x86_64 signed binaries only. This does not abort
# on aarch64 any more (issue #1 predates AUR-fallback support) — it just
# tells the operator which mode the run is in, since a fallback run builds
# non-official tools from the AUR and takes noticeably longer.
#
# On x86_64 (ONIOMARCHY_AUR_FALLBACK empty) this is a silent no-op. This
# is also the single place a future hard-stop for a genuinely-unsupported
# arch would go.
if [[ -n ${ONIOMARCHY_AUR_FALLBACK:-} ]]; then
  echo "==> Architecture $(uname -m): [oniomarchy] is x86_64-only, so"
  echo "    non-official tools will be built from the AUR (this is slower)."
fi
