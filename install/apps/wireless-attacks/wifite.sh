# wifite — Wireless Attacks
# pack: core
pkg_official wifite
# wifite shells out to reaver for WPS attacks; not pulled in by wifite's own deps
pkg_official reaver
# alternative WPS attack engine wifite also shells out to
pkg_official bully
# WPA handshake dictionary attack wifite also shells out to
pkg_official cowpatty
# fake-AP/karma-style attacks wifite also shells out to
pkg_official hostapd
# reaver's own pixie-dust mode shells out to this; not in reaver's own deps
pkg_official pixiewps
