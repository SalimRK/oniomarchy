#!/usr/bin/env bash
#
# Fetch an intercepting proxy's CA certificate and add it to the SYSTEM
# trust store — the launch target for Trigger > Pentest > Trust Proxy CA.
# Installed to /usr/local/bin/oniomarchy-proxy-trust by
# install/trigger/install-scripts.sh.
#
# Usage:
#   oniomarchy-proxy-trust              # Burp on its default port 8080
#   oniomarchy-proxy-trust 8081         # some other port
#   oniomarchy-proxy-trust ~/ca.crt     # a cert exported by hand (Caido)
#
# Why the system store rather than Firefox's own `Certificates.Install`
# policy: one import then covers Firefox, Chromium AND curl, instead of
# Firefox alone. The Firefox side is already switched on — policies.json
# sets Certificates.ImportEnterpriseRoots, which is what makes Firefox
# consult the OS store at all.
#
# Why this is a menu action and not part of install.sh: Burp serves its CA
# from http://127.0.0.1:8080/cert only while Burp is RUNNING, so there is
# nothing to fetch at install time. Burp also regenerates its CA per
# installation, so this is expected to be run more than once — it
# overwrites its own anchor in place rather than accumulating copies.

set -euo pipefail

anchors=/etc/ca-certificates/trust-source/anchors

if (( EUID != 0 )); then
  echo "This needs root (it writes to $anchors)." >&2
  echo "Run:  sudo oniomarchy-proxy-trust $*" >&2
  exit 1
fi

arg="${1:-8080}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
raw="$tmp/ca.raw"

if [[ -f $arg ]]; then
  source_desc="file $arg"
  cp -- "$arg" "$raw"
else
  if [[ ! $arg =~ ^[0-9]+$ ]]; then
    echo "Not a port number and not an existing file: $arg" >&2
    exit 1
  fi

  url="http://127.0.0.1:$arg/cert"
  source_desc="$url"

  # Fail on the connection rather than on the parse: "proxy isn't running"
  # is by far the likeliest reason to be here, and it deserves its own
  # message instead of a confusing openssl error further down.
  if ! curl -fsS --connect-timeout 3 --max-time 15 -o "$raw" "$url"; then
    echo "Could not fetch a certificate from $url" >&2
    echo >&2
    echo "Is the proxy running and listening on port $arg?" >&2
    echo "Burp serves its CA at /cert only while Burp itself is open." >&2
    echo "For Caido, export the CA from its own settings and pass the file:" >&2
    echo "    sudo oniomarchy-proxy-trust /path/to/ca.crt" >&2
    exit 1
  fi
fi

[[ -s $raw ]] || { echo "Fetched an empty certificate from $source_desc" >&2; exit 1; }

# Normalize to PEM. Burp's /cert serves DER; a hand-exported file is
# usually PEM. Try both before trusting anything — installing an
# unvalidated blob into the system trust store is the one genuinely
# dangerous thing this script could do.
pem="$tmp/ca.pem"
if openssl x509 -inform DER -in "$raw" -out "$pem" 2>/dev/null; then
  form=DER
elif openssl x509 -inform PEM -in "$raw" -out "$pem" 2>/dev/null; then
  form=PEM
else
  echo "What came back from $source_desc is not a certificate." >&2
  echo "First bytes:" >&2
  head -c 120 "$raw" | tr -c '[:print:]\n' '.' >&2
  echo >&2
  exit 1
fi

subject=$(openssl x509 -in "$pem" -noout -subject 2>/dev/null || true)
expires=$(openssl x509 -in "$pem" -noout -enddate 2>/dev/null | cut -d= -f2- || true)

# A proxy CA that is not a CA would silently fail to validate anything.
if ! openssl x509 -in "$pem" -noout -text 2>/dev/null | grep -q 'CA:TRUE'; then
  echo "Warning: this certificate is not marked as a CA (no CA:TRUE)." >&2
  echo "Installing it anyway, but it will probably not do what you want." >&2
fi

# Name the anchor after the certificate's own CN, so Burp's CA and Caido's
# CA coexist instead of overwriting each other — while re-running against
# the SAME proxy still replaces its previous CA in place, which is what
# makes this safe to run repeatedly after Burp regenerates one.
cn=$(openssl x509 -in "$pem" -noout -subject -nameopt multiline 2>/dev/null \
     | sed -n 's/^ *commonName *= *//p' | head -1)
slug=$(printf '%s' "${cn:-proxy}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')
dest="$anchors/oniomarchy-proxy-${slug:-ca}.crt"

replacing=""
[[ -f $dest ]] && replacing=" (replacing the previous one)"

install -Dm644 "$pem" "$dest"
update-ca-trust

echo "==> Trusted the proxy CA$replacing"
echo "    source:  $source_desc  [$form]"
echo "    ${subject:-subject unavailable}"
echo "    expires: ${expires:-unknown}"
echo "    stored:  $dest"
echo
echo "Firefox, Chromium and curl now trust it. Restart the browser if it"
echo "was already open."
