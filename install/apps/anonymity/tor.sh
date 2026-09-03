# tor — Anonymity
# pack: core
#
# torsocks and iptables ship alongside tor because the toolkit's anonymity
# story needs both: torsocks to route an arbitrary binary through the SOCKS
# port, iptables as the transparent-proxy/kill-switch substrate.
#
# The Tor *toggle* is not built here — that's the third-party `tormarchy`
# plugin (install/widgets/tormarchy.sh), which runs its own `setup` and
# installs its own tor config snippet and polkit rule.
pkg_official tor torsocks iptables
