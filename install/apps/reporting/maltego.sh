# maltego — Reporting Tools
# pack: core
pkg_aur maltego

# Maltego's NetBeans-platform launcher tries to enable Java's Security
# Manager, which JDK 24+ permanently removed (JEP 486) — a fatal
# "Enabling a Security Manager is not supported" VM-boot error on any
# system whose default `java` is JDK 24+. The package correctly depends
# on java-environment=17 (pacman/yay resolve that to jdk17-openjdk
# automatically, no separate pkg_official needed here), but the launcher
# only picks it up if told to: it reads a user-level override at
# ~/.maltego/<version>/etc/maltego.conf, sourced after — and overriding —
# the package's own root-owned /opt/maltego/etc/maltego.conf. That file
# only needs the one line that differs; default_options stays whatever
# the package conf already set, since sourcing a script that doesn't
# reassign a variable leaves it untouched.
#
# A stale copy of this file from an earlier failed launch (pointing
# jdkhome at /usr/lib/jvm/default, i.e. whatever JDK happens to be the
# system default) is just as broken and does not self-heal: the launcher
# only treats jdkhome as invalid if the directory is missing, not if
# it's merely the wrong JDK version — so this unconditionally overwrites
# it rather than checking first. Verified live 2026-09-03: reproduced the
# exact VM-boot crash, applied this fix, relaunched from the real
# Security menu — Maltego's main window and welcome dialog both opened.
maltego_userdir_suffix=$(grep -oP 'default_userdir="\$\{DEFAULT_USERDIR_ROOT\}/\K[^"]+' /opt/maltego/etc/maltego.conf)
maltego_userdir="$HOME/.maltego/${maltego_userdir_suffix:-v4.8.1}/etc"
mkdir -p "$maltego_userdir"
echo 'jdkhome="/usr/lib/jvm/java-17-openjdk"' > "$maltego_userdir/maltego.conf"
