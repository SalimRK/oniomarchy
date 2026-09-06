# maltego — Reporting Tools
# pack: core
pkg_repo maltego

# Maltego's NetBeans-platform launcher tries to enable Java's Security
# Manager, which JDK 24+ permanently removed (JEP 486) — a fatal
# "Enabling a Security Manager is not supported" VM-boot error on any
# system whose default `java` is JDK 24+. The package correctly depends
# on java-environment=17 (pacman resolves that to jdk17-openjdk
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
# The suffix is READ from the package's own conf, not assumed — Maltego
# changes it with every release and it is the whole address of the file
# being written. The literal below is only the fallback for a conf that
# cannot be read at all, and it tracks whatever [oniomarchy] currently
# ships: v4.12.1, confirmed by extracting opt/maltego/etc/maltego.conf
# straight out of maltego-4.12.1-1-any.pkg.tar.zst (2026-09-06, bumped
# from a stale v4.8.1). A wrong fallback is silent — the file lands in a
# directory the launcher never reads, and Maltego fails exactly as if
# nothing had been written.
maltego_userdir_suffix=$(grep -oP 'default_userdir="\$\{DEFAULT_USERDIR_ROOT\}/\K[^"]+' /opt/maltego/etc/maltego.conf)
maltego_userdir="$HOME/.maltego/${maltego_userdir_suffix:-v4.12.1}/etc"
mkdir -p "$maltego_userdir"
echo 'jdkhome="/usr/lib/jvm/java-17-openjdk"' > "$maltego_userdir/maltego.conf"
