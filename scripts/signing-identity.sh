# Source from the repository root. Never silently fall back to ad-hoc signing.
identity_file="$PWD/.build-tools/signing/identity.txt"
if [ ! -f "$identity_file" ]; then
  echo 'Stable signing identity is not configured. Run ./scripts/setup-dev-signing.sh once.' >&2
  exit 1
fi
IFS= read -r CLAURST_SIGNING_IDENTITY < "$identity_file"
case "$CLAURST_SIGNING_IDENTITY" in *[!0-9A-F]*|'') echo 'Invalid pinned signing fingerprint.' >&2; exit 1 ;; esac
[ "${#CLAURST_SIGNING_IDENTITY}" -eq 40 ] || { echo 'Invalid pinned signing fingerprint.' >&2; exit 1; }
if ! security find-identity -p codesigning | awk -v fingerprint="$CLAURST_SIGNING_IDENTITY" '$2 == fingerprint { found=1 } END { exit !found }'; then
  echo 'Pinned signing identity is unavailable. Restore this certificate and its private key; do not replace it automatically.' >&2
  exit 1
fi
sign_development_code() {
  code_path=$1
  code_identifier=$2
  codesign --force --sign "$CLAURST_SIGNING_IDENTITY" --identifier "$code_identifier" \
    --requirements "=designated => identifier \"$code_identifier\" and certificate leaf = H\"$CLAURST_SIGNING_IDENTITY\"" "$code_path"
  codesign --verify --strict -R "=identifier \"$code_identifier\" and certificate leaf = H\"$CLAURST_SIGNING_IDENTITY\"" "$code_path"
}
