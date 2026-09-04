# wifite — Wireless Attacks
# pack: core
pkg_official wifite
pkg_official reaver # wifite shells out to reaver for WPS attacks; not pulled in by wifite's own deps
pkg_official bully # alternative WPS attack engine wifite also shells out to
pkg_official cowpatty # WPA handshake dictionary attack wifite also shells out to
pkg_official hostapd # fake-AP/karma-style attacks wifite also shells out to
pkg_official pixiewps # reaver's own -K pixie-dust mode shells out to this; not in reaver's own deps
