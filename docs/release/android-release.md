# Android release — SCRUM-102

Release builds use the external upload keystore; debug-key fallback is removed.
Debug builds still work without release credentials. `assembleRelease`, `bundleRelease`
and signing validation require the explicit release guard. No key/password/property
file belongs in Git. An environment override `FCOURT_SIGNING_PROPERTIES_FILE` can point
to a private UTF-8 Java properties file containing storeFile, storePassword, keyAlias,
keyPassword; otherwise Gradle reads ignored android/key.properties. storeFile may be an
absolute path. Keep the key backed up securely; this change never generates a real
production key or replaces an existing application signing identity.

## GitHub inputs

Repository secrets:

- ANDROID_KEYSTORE_BASE64: base64 of the existing private upload keystore.
- ANDROID_KEY_ALIAS
- ANDROID_KEY_PASSWORD
- ANDROID_STORE_PASSWORD

Repository variable PRODUCTION_API_BASE_URL must be the actual deployed HTTPS API.
Missing inputs, placeholder/non-HTTPS hosts and androiddebugkey aliases fail closed.
`prepare_android_release.py` writes private files (directory 0700/files 0600) under the
runner temporary directory and exports file paths only. Secrets are never command-line
arguments or logs. The final cleanup removes those files; hosted runner teardown is an
additional boundary. GitHub secret values must be configured through account settings,
not sent through chat or committed.

## Workflow and verification

Android release workflow runs quality checks and a signing smoke for Android/tooling
PRs into dev/main, pushes to main and manual dispatch. Production artifact generation
runs only for main after the signing smoke succeeds; PR jobs never receive the real
signing secrets. Flutter is pinned to 3.47.7 with JDK 17; Android setup supplies command-line/build tools and hosted Gradle memory/workers are bounded. Both signed app-release.apk and
app-release.aab are uploaded as Actions artifacts keyed by commit SHA, retained 14 days.
No tag, GitHub Release, Play upload or deployment is automatically published.

`verify_android_release.py` uses apksigner and jarsigner to verify both artifacts and
compares both signer certificates against the configured keystore's SHA-256 fingerprint.
It rejects unsigned bundle entries and mismatched signers. Android SDK build-tools,
keytool and jarsigner are required.

`python3 tool/android_signing_smoke.py` copies the source into a disposable directory,
checks that missing configuration fails at the guard, creates a throwaway two-day test
key, builds release APK/AAB against signing-smoke.invalid and verifies signatures.
The temporary checkout, key and signed fixtures are deleted; they are never uploaded
or offered as production artifacts. This verifies mechanics, not a production signing
identity, connectivity or Android 8–14 installation acceptance.

Production release acceptance is pending: SCRUM-100 is not deployed, integrated main
and real HTTPS/signing inputs are unavailable. Configure the existing key and backend,
review/merge dependencies, run the protected main workflow and install its real signed
artifact on supported devices before marking the Jira task Done.

References: https://docs.flutter.dev/deployment/android and
https://docs.github.com/en/actions/tutorials/store-and-share-data.

## Local validation

`actionlint` and Python compilation pass. The missing-key guard, signed release APK,
signed AAB and matching certificate verification pass in a disposable checkout using
a temporary key; all fixtures/key are deleted afterward. Android command-line tools
were installed from the official Google archive with checksum verification to enable
Flutter bundle validation. Debug APK also builds without release credentials.
Production signing identity and device/backend acceptance remain pending.
