#!/bin/sh
# Compare two actual bundles, including mutual designated-requirement validation.
set -eu
[ "$#" -eq 2 ] || { echo 'Usage: test-signing-continuity.sh first.app second.app' >&2; exit 2; }
first=$1
second=$2
first_requirement=$(codesign -d -r- "$first" 2>&1 | sed -n 's/^designated => //p;s/^# designated => //p')
second_requirement=$(codesign -d -r- "$second" 2>&1 | sed -n 's/^designated => //p;s/^# designated => //p')
[ -n "$first_requirement" ] && [ "$first_requirement" = "$second_requirement" ] || {
  echo 'FAIL: successive builds have different designated requirements' >&2; exit 1;
}
case "$first_requirement" in *cdhash*) echo 'FAIL: identity is tied to one binary hash' >&2; exit 1 ;; esac
codesign --verify --strict -R "=$first_requirement" "$second"
codesign --verify --strict -R "=$second_requirement" "$first"
printf 'PASS: successive builds satisfy the same certificate-bound identity\n'
