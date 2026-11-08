#!/usr/bin/env bash
set -euo pipefail

build_log=$(mktemp)
trap 'rm -f "$build_log"' EXIT

for attempt in 1 2 3; do
  if flutter build apk --debug --dart-define-from-file=env/dev.json 2>&1 | tee "$build_log"; then
    exit 0
  else
    build_status=$?
  fi

  if (( attempt == 3 )) || ! grep -Eq \
    'Received status code (429|500|502|503|504)|Server returned HTTP response code: (429|500|502|503|504)|Gradle threw an error while downloading artifacts from the network' \
    "$build_log"; then
    exit "$build_status"
  fi

  delay=$((attempt * 15))
  echo "Dependency download failed; retrying Android build in ${delay}s (attempt $((attempt + 1))/3)."
  sleep "$delay"
done
