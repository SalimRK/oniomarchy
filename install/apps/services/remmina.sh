# remmina — Services
# pack: core
#
# The remote-desktop story in Oniomarchy, and since 2026-09-06 the whole
# of it. This leaf was added alongside xrdp, which installed the *server*
# half — what lets another machine connect INTO this box. xrdp was then
# dropped from the toolkit entirely: it serves an X session, and
# Oniomarchy is Wayland-only Hyprland, so it was never going to hand a
# connecting client a useful desktop. remmina connects OUT, to the RDP and
# VNC hosts that turn up during an engagement, which is the direction that
# actually matters here.
#
# No services.tsv row, deliberately. Every other leaf in this category
# (apache, nginx, openssh, postgresql) ships a systemd unit and appears in
# the Trigger > Pentest > Services menu; remmina is a GUI client with no
# daemon, so there is nothing to start, stop or gate. It gets no
# security/categories.tsv row either — no services/ package has one.
# Instead it has its own launcher directly under Trigger > Pentest, next
# to the reverse-shell listener and the HTTP file server (see
# install/trigger/menu.sh).
#
# freerdp and libvncserver are named here because remmina declares them
# as *optdepends*, so pacman will not pull them in, and without them
# `remmina` installs a remote-desktop client that cannot speak either
# protocol it exists for — a silent, GUI-level failure rather than an
# install error. Same reasoning as nikto.sh's perl-xml-writer. freerdp is
# what lets it talk to Windows RDP; libvncserver covers VNC. Both are in
# extra (freerdp 3.31.1, libvncserver 0.9.15, confirmed against
# archlinux.org's package API 2026-09-06 — the local sync db on the build
# host was twelve days stale).
#
# Deliberately NOT installed:
#   spice-gtk  - Spice is a virtual-machine console protocol, not
#                something found on a target network.
#   gtk-vnc    - a second, redundant VNC backend; libvncserver already
#                covers the protocol.
#   libsecret  - saved-credential storage. Present on the build host
#                already (core, via gnome-keyring), so naming it looked
#                like noise; if a clean Omarchy base turns out not to
#                pull it in, remmina will silently forget saved
#                passwords and it belongs on the line below.
#
# Kept on ONE line with no backslash continuation: lib/prefetch.sh
# collects the prefetch list with a line-based grep, and a continuation
# both captures the trailing backslash as a package name and silently
# drops everything after it. See recon-ng.sh.
pkg_official remmina freerdp libvncserver
