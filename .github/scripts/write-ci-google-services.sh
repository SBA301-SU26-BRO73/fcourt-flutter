#!/usr/bin/env bash
# CI has no real Firebase config (android/app/google-services.json is gitignored).
# Write a placeholder so the google-services Gradle plugin can run. It holds no
# real project data and is never used for release artifacts that get published.
set -euo pipefail

target="${1:-android/app/google-services.json}"
[ -e "$target" ] && exit 0

cat > "$target" <<'JSON'
{
  "project_info": {
    "project_number": "000000000000",
    "project_id": "ci-placeholder",
    "storage_bucket": "ci-placeholder.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:000000000000:android:0000000000000000000000",
        "android_client_info": { "package_name": "com.bro73.fcourt" }
      },
      "api_key": [{ "current_key": "ci-placeholder-api-key" }]
    }
  ],
  "configuration_version": "1"
}
JSON
