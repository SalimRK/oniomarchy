# Oniomarchy

**The hacker's omakase.**

A cybersecurity workstation built as an overlay on
[Omarchy](https://omarchy.org/) — Arch Linux, Hyprland, Quickshell.

Not "Omarchy with Kali tools." A usable OS for security people.

[oniomarchy.com](https://oniomarchy.com)

---

## What it is

- **An overlay.** You install it on top of a stock Omarchy system. Run
  `./install.sh` and you have Oniomarchy.
- **One application, one script.** Every tool has its own leaf under
  `install/apps/<category>/`, installing exactly that app and whatever it
  alone needs.
- **Signed, prebuilt packages.** Tools install as binaries from a signed
  pacman repository — nothing compiles on your machine.
- **Menu-native.** Tools, services and quick actions land in the Omarchy
  launcher you already use, not in a separate app.

## What it is not

- Not a fork of Omarchy, and not a custom ISO.
- Not a replacement for your distro — it adds to an Omarchy install
  rather than becoming one.
- It never writes to `/usr/share/omarchy/`. That directory is
  package-owned and gets wiped on `omarchy update`; everything here goes
  through the `omarchy` CLI and your own config, so it survives updates.

## Requirements

A working [Omarchy](https://omarchy.org/) install. The first thing
`install.sh` does is check for the `omarchy` command and refuse to run
without it.

Budget several gigabytes of disk. The default set is curated with that in
mind — the heaviest tools (Autopsy, Burp Suite) sit deliberately outside
it and are one flag away when you want them.

## Install

```bash
git clone https://github.com/SalimRK/oniomarchy.git
cd oniomarchy
./install.sh
```

It asks for your password once, up front, and then runs unattended.

What it changes on your machine:

1. Adds `[oniomarchy]`, the signed binary package repository, to
   `/etc/pacman.conf`.
2. Installs the `oniomarchy` command.
3. Installs the curated default tool set — 56 of the 86 available.
4. Merges its menu entries into
   `~/.config/omarchy/extensions/omarchy-menu.jsonc`.
5. Installs the Tor, MAC-randomization and GoDark (cut every radio and
   network link) bar plugins, the per-theme wallpapers, and the oni
   branding.
6. Adds a post-update hook so `omarchy update` keeps Oniomarchy current
   too — see [Updating](#updating).

Every run writes a full log to
`~/.local/state/oniomarchy/install-<timestamp>.log`, with a `latest.log`
symlink beside it — in both quiet and verbose mode, always.

```bash
./install.sh --verbose   # show every package manager line as it happens
./install.sh --help      # all options, including --log and --no-log
```

## Updating

```bash
omarchy update
```

That's all. Omarchy's update upgrades every package, including the
tools from `[oniomarchy]`, and then runs Oniomarchy's hook, which pulls
the latest Oniomarchy and re-runs the installer if anything changed —
new tools, menu entries, widgets or art. When nothing changed it adds
about a second.

Updates come from Oniomarchy's own copy of the repository in
`~/.local/share/oniomarchy/repo`, so it doesn't matter where you cloned
it to install, or whether you still have that clone.

The bar plugins update the same way, but they show you what changed and
ask first, since the Tor plugin's setup runs as root. Under
`omarchy update -y`, where nobody is there to answer, plugins are left
alone; run `oniomarchy update` to review them.

`oniomarchy update` also works on its own, without a system update.
To turn the hook off (for example on a machine where you develop
Oniomarchy and want to install from your own checkout):

```bash
mkdir -p ~/.config/oniomarchy && touch ~/.config/oniomarchy/no-auto-update
```

## Packs

The default is curated, not everything.

```bash
./install.sh                  # the curated default — 56 tools
./install.sh --pack all       # every leaf in the tree — 86
./install.sh --pack sdr       # one category's curated slice
./install.sh --pack sdr-all   # one category, everything in it
./install.sh --list-packs     # every pack name, with counts
```

**`--pack` replaces the default selection — it does not add to it.**
`--pack sdr` installs SDR's slice and nothing else, never core plus SDR.
Pack names combine, so `--pack core,sdr-all` is how you say "the usual,
plus all of SDR."

| Category | `--pack <name>` | `--pack <name>-all` |
|---|---|---|
| ai-tools | 1 | 1 |
| anonymity | 2 | 2 |
| automotive | 1 | 1 |
| digital-forensics | 5 | 7 |
| exploitation | 4 | 5 |
| information-gathering | 7 | 8 |
| password-attacks | 5 | 5 |
| post-exploitation | 4 | 5 |
| privacy | 3 | 3 |
| reporting | 3 | 3 |
| reverse-engineering | 3 | 5 |
| sdr | 4 | 16 |
| services | 5 | 5 |
| sniffing-spoofing | 3 | 4 |
| social-engineering | 2 | 2 |
| vulnerability-analysis | 3 | 3 |
| web-application-analysis | 4 | 6 |
| wireless-attacks | 3 | 5 |

## What you get

**A Security menu.** Everything you installed, grouped into 15
categories — Information Gathering, Vulnerability Analysis, Web
Application Analysis, Password Attacks, Wireless Attacks, SDR, Reverse
Engineering, Exploitation, Sniffing & Spoofing, Post Exploitation,
Digital Forensics, Reporting, Social Engineering, Automotive, AI Tools.
The menu is generated by asking pacman what each package actually
installed, so entries point at real binaries and real desktop files
rather than guessed names.

Pick a command-line tool and it shows you its own usage first, with your
machine's IP addresses already printed, and hands you a shell — never a
blank prompt, never a blind run. GUI tools launch directly.

**A Webapps category.** 18 security sites — CyberChef, GTFOBins, LOLBAS,
Shodan, Exploit-DB, revshells.com, ATT&CK Navigator and more — installed
as real Omarchy web apps.

**Quick actions**, under `Trigger > Pentest`: a reverse-shell listener, an
HTTP file server (your own directory, or one click to host linpeas or
winpeas), proxy CA trust, and Remmina.

**Services** you can start and stop from the menu: SSH, PostgreSQL,
Apache, Nginx, BeEF. The two that expose something — SSH and BeEF — ask
for confirmation before starting, and never before stopping. All of them
ship inactive.

**Bar widgets** for Tor and MAC randomization, installed through
Omarchy's own plugin system.

**Branding**: 44 per-theme 4K wallpapers — an ONIOMARCHY wordmark and an
oni-mask lockup for each of Omarchy's 22 themes — plus the oni mask in
your About screen and screensaver.

## The `oniomarchy` command

Everything in the menus, from a terminal:

```
oniomarchy tool      list / help / run a tool from the Security menu
oniomarchy service   list / start / stop / restart a service
oniomarchy net       revshell, http-server, linpeas, winpeas, proxy-trust, remmina
oniomarchy repo      [oniomarchy] repo status / strap / remove
oniomarchy branding  install / reset the oni art
oniomarchy doctor    re-verify every tool and service still resolves
oniomarchy update    pull the latest Oniomarchy and plugins, re-run the installer
```

`tool list`, `service list` and `doctor` all take `--json`. Run
`oniomarchy <group> --help` for a group's own subcommands.

## Where things go

| | |
|---|---|
| Menu entries | `~/.config/omarchy/extensions/omarchy-menu.jsonc` |
| Wallpapers | `~/.config/omarchy/backgrounds/<theme>/` |
| Branding art | `~/.config/omarchy/branding/` |
| Logs and state | `~/.local/state/oniomarchy/` |
| Update copy of the repo | `~/.local/share/oniomarchy/repo` |
| Post-update hook | `~/.config/omarchy/hooks/post-update.d/oniomarchy-update.hook` |
| The CLI | `/usr/local/bin/oniomarchy` |

Menu entries are merged between `BEGIN`/`END` markers, so re-running the
installer is safe and an `omarchy update` leaves them alone.

## Packages are signed

Tools install as prebuilt binaries from `pkgs.oniomarchy.com`, verified
against a signing key pinned by fingerprint:

```
0F5F9214F312B067ECBF1DF125E2C00AA6340BD0
```

`SigLevel` is `Required DatabaseRequired` — both the packages and the
database must verify. Fetching the key over HTTPS is safe precisely
because the fingerprint is hard-coded in `install/repo/strap.sh`: TLS
proves you reached the server, the fingerprint proves the key is ours.

**There is no AUR fallback, on purpose.** If the repository can't serve
something, the install stops and names it. The alternative is silently
dropping you into an hour of compiling with no idea why.

To inspect or undo it: `oniomarchy repo status`, `oniomarchy repo remove`.

## Adding a tool

One app, one script. Drop a leaf at `install/apps/<category>/<app>.sh`
that installs that app and its own dependencies. Leaves are discovered
with `find`, so there is no manifest to update. Add a row to
`install/security/categories.tsv` to give it a Security-menu entry, and
tag it `# pack: core` if it belongs in the default set.

Syntax-check everything before you commit:

```bash
bash -n install.sh $(find install -name '*.sh')
```

## Authorized use

These are tools for finding and exploiting weaknesses in computer
systems. Use them only on systems you own or have written permission to
test.

Nothing installed here is enabled or listening by default. Every service
ships inactive, and the two that expose a port ask before they start.

## License

MIT — see [LICENSE](LICENSE).

Omarchy is MIT-licensed and copyright David Heinemeier Hansson.
Oniomarchy is an independent project and is not affiliated with or
endorsed by the Omarchy project.
