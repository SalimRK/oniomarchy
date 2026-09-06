# supersdr — Software Defined Radio
#
# tk is an undeclared runtime dep in the AUR PKGBUILD (supersdr imports
# tkinter) — found by the 2026-09-03 GUI audit and worked around here with
# a bare `pkg_official tk`. Our packaged PKGBUILD declares it, so pacman
# pulls it in.
#
# python-sounddevice, another of its dependencies, is deliberately NOT
# published by [oniomarchy] — [omarchy] ships a byte-identical version and
# is configured first, so it wins. Nothing to do here; noted because it is
# the one dependency in this toolkit that crosses repositories.
pkg_repo supersdr
