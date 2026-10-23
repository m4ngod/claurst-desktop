#!/bin/sh
# One-time local development identity. No broad trust changes or API-key access.
set -eu
cd "$(dirname "$0")/.."
umask 077
signing_dir="$PWD/.build-tools/signing"
mkdir -p "$signing_dir"
identity_file="$signing_dir/identity.txt"
certificate_name='Claurst Desktop Local Development'
if [ "$#" -gt 0 ]; then
  [ "$#" -eq 2 ] && [ "$1" = --identity ] || { echo 'Usage: setup-dev-signing.sh [--identity SHA1]' >&2; exit 2; }
  selected=$(printf '%s' "$2" | tr 'a-f' 'A-F')
  case "$selected" in *[!0-9A-F]*|'') echo 'Expected a certificate SHA-1 fingerprint.' >&2; exit 1 ;; esac
  [ "${#selected}" -eq 40 ] || { echo 'Expected a certificate SHA-1 fingerprint.' >&2; exit 1; }
  security find-identity -v -p codesigning | awk -v fingerprint="$selected" '$2 == fingerprint { found=1 } END { exit !found }' || {
    echo 'Selected trusted signing identity is unavailable; pinned identity unchanged.' >&2; exit 1;
  }
  # Only an explicit identity selection can replace the pin. Routine builds
  # and repeated setup never rotate it or select the first available identity.
  temporary=$(mktemp "$signing_dir/.identity-XXXXXX")
  printf '%s\n' "$selected" > "$temporary"
  mv "$temporary" "$identity_file"
  . scripts/signing-identity.sh
  printf 'Pinned selected signing certificate: %s\n' "$CLAURST_SIGNING_IDENTITY"
  exit 0
fi
if [ -f "$identity_file" ]; then
  . scripts/signing-identity.sh
  printf 'Using existing pinned development certificate: %s\n' "$CLAURST_SIGNING_IDENTITY"
  exit 0
fi
identities=$(security find-identity -p codesigning | awk -v name="$certificate_name" 'index($0, "\"" name "\"") { print $2 }' | sort -u)
if [ -z "$identities" ]; then
  scratch=$(mktemp -d "$signing_dir/setup-XXXXXX")
  trap 'rm -rf "$scratch"' EXIT HUP INT TERM
  cat > "$scratch/certificate.cnf" <<'CONFIG'
[req]
distinguished_name = subject
x509_extensions = signing
prompt = no
[subject]
CN = Claurst Desktop Local Development
[signing]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
CONFIG
  /usr/bin/openssl req -new -x509 -newkey rsa:3072 -nodes -days 3650 \
    -config "$scratch/certificate.cnf" -keyout "$scratch/private.pem" -out "$scratch/certificate.pem" 2> "$scratch/generate.log"
  /usr/bin/openssl rand -hex 32 > "$scratch/password"
  /usr/bin/openssl pkcs12 -export -inkey "$scratch/private.pem" -in "$scratch/certificate.pem" \
    -name "$certificate_name" -out "$scratch/identity.p12" -passout "file:$scratch/password"
  IFS= read -r import_password < "$scratch/password"
  # Allow only Apple's codesign tool to use this newly generated signing key.
  # Import into the user's default keychain; do not alter existing key ACLs.
  security import "$scratch/identity.p12" -f pkcs12 -P "$import_password" -T /usr/bin/codesign
  unset import_password
  identities=$(/usr/bin/openssl x509 -in "$scratch/certificate.pem" -noout -fingerprint -sha1 | sed 's/.*=//;s/://g')
fi
case "$identities" in *[!0-9A-F]*|'') echo 'Expected one unambiguous local development certificate; no identity pinned.' >&2; exit 1 ;; esac
[ "${#identities}" -eq 40 ] || { echo 'Unexpected certificate fingerprint; no identity pinned.' >&2; exit 1; }
printf '%s\n' "$identities" > "$identity_file"
. scripts/signing-identity.sh
printf 'Pinned local development certificate: %s\n' "$CLAURST_SIGNING_IDENTITY"
printf 'Its private key stays in the Keychain. This is not a public distribution identity.\n'
printf 'A self-signed certificate does not prevent login-Keychain partition prompts after code changes. Use an Apple-issued identity for that.\n'
