#!/usr/bin/env bash
# Chạy một lệnh và chỉ chạy lại khi log khớp dấu hiệu lỗi mạng/tải về tạm thời.
# Lỗi code, lỗi analyze, test fail không khớp mẫu nào nên không bao giờ bị chạy lại.
#
# Dùng: retry-on-network-error.sh <lệnh> [đối số...]
set -uo pipefail

max_attempts="${RETRY_MAX_ATTEMPTS:-3}"
base_delay="${RETRY_BASE_DELAY:-30}"

transient='Received status code (429|500|502|503|504)|Server returned HTTP response code: (429|500|502|503|504)|Gradle threw an error while downloading artifacts from the network|Hash of downloaded file .* is [0-9a-f]+, expected [0-9a-f]+|Could not (GET|HEAD|resolve) |Connection (reset|timed out)|Read timed out|SocketException|Temporary failure in name resolution|Failed host lookup|HandshakeException|Could not download'

log=$(mktemp)
trap 'rm -f "$log"' EXIT

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  "$@" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  [ "$status" -eq 0 ] && exit 0

  if (( attempt == max_attempts )) || ! grep -Eq "$transient" "$log"; then
    exit "$status"
  fi

  delay=$((attempt * base_delay))
  echo "::warning::Lỗi tải phụ thuộc tạm thời; chạy lại sau ${delay}s (lần $((attempt + 1))/${max_attempts}): $*"
  sleep "$delay"
done
