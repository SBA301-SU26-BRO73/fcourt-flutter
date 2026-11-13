#!/usr/bin/env bash
set -euo pipefail

# Chỉ chạy lại khi lỗi do tải phụ thuộc (Gradle distribution, Maven, native assets); xem script retry.
exec bash "$(dirname "$0")/retry-on-network-error.sh" \
  flutter build apk --debug --dart-define-from-file=env/dev.json
