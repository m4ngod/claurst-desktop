#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ ! -f .build/latest-desktop-app.txt ]; then
  printf 'Build the app first with ./scripts/build-desktop.sh\n' >&2
  exit 1
fi
IFS= read -r app < .build/latest-desktop-app.txt
if [ ! -d "$app" ]; then
  printf 'The latest build is missing. Run ./scripts/build-desktop.sh again.\n' >&2
  exit 1
fi
exec open -n "$app"
