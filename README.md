# fcourt-flutter

Android app of FCourt, a sports court booking system. One app serves four roles: customers (discover branches, pick slots, book and pay, booking history, reviews), court owners/admins (dashboard, branches, courts, slot templates, weekly schedule, vouchers, reports), staff (QR check-in, counter booking, POS, offline check-in) and super admins (approve owner applications). Push notifications use Firebase Cloud Messaging.

Built with Flutter and Clean Architecture, split by feature. Android is the supported target; the `ios/` and `web/` targets exist mainly for UI review.

## Role in the FCourt system

| Repo | Responsibility |
|---|---|
| `fcourt-backend` | Spring Boot microservices the app calls over HTTPS |
| `fcourt-web` | Web frontend (https://fcourt.donan.site) |
| **fcourt-flutter** (this repo) | Android app |
| `fcourt-gitops` | Argo CD manifests deploying the backend to EKS |
| `fcourt-infra` | Terraform for AWS (VPC, EKS, ECR, S3, CloudFront, Route 53, ACM, ...) |

## Tech stack

Flutter 3.47.7 (stable) with Dart 3.13.5, `flutter_bloc`, `dio`, `go_router`, `flutter_secure_storage`, `freezed`/`json_serializable`, `firebase_messaging`, `mobile_scanner`, `sqflite` (offline check-in), `workmanager`, `fl_chart`. Tests use `bloc_test` and `mocktail`. See `pubspec.yaml` for the full list.

## Project structure

```text
fcourt-flutter
|- lib
|  |- main.dart            # entry point, builds AppDependencies
|  |- app                  # app.dart, router.dart, app_dependencies.dart, theme
|  |- core                 # config (AppConfig), error, network (Dio, AuthInterceptor), storage
|  |- features             # one folder per feature: data / domain / presentation
|  |- src/features         # older customer features (discovery, slots, gallery)
|- test                    # unit, bloc and widget tests
|- env                     # dev.json, prod.json (dart-define files, no secrets)
|- android, ios, web       # platform projects
|- tool                    # Android release signing scripts and their tests (Python)
|- .github                 # workflows, setup-flutter action, scripts
|- docs                    # documentation, see docs/README.md
|- PRODUCT.md              # product and UX principles
```

Dependency rule: `presentation -> domain <- data`. How to add a feature: [lib/features/README.md](lib/features/README.md).

## Prerequisites

- Flutter 3.47.7 (pinned in `.github/actions/setup-flutter/action.yml`).
- Android Studio or the Android SDK, and an emulator or device.
- A backend: local services (see `fcourt-backend`) or the deployed one.
- `android/app/google-services.json` for the FCourt Firebase project (Firebase Console, Project settings, Your apps, FCourt Android, Download). The file is git-ignored; never commit or share it.

## Setup, run, test

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json     # local backend, seen from the emulator
flutter run --dart-define-from-file=env/prod.json    # deployed backend
```

| Command | Purpose |
|---|---|
| `flutter analyze --fatal-infos --fatal-warnings` | Static analysis, same strictness as CI |
| `flutter test` | Unit, bloc and widget tests |
| `dart run build_runner build` | Regenerate freezed/json code |
| `flutter build apk --debug --dart-define-from-file=env/dev.json` | Debug APK (what the CI smoke build does) |
| `flutter run -d chrome --web-hostname=127.0.0.1 --web-port=18100 --dart-define=API_BASE_URL=http://127.0.0.1:18080` | UI review in a browser; camera, gallery saving, push and offline native features need Android |

On a physical phone, set `API_BASE_URL` in your local copy of `env/dev.json` to the LAN IP of the backend machine and do not commit it. Debug builds allow cleartext HTTP; release builds allow HTTPS only.

## Configuration

Config is read at build time through `--dart-define-from-file`. Env files are committed, so they must hold no secrets.

| File | `API_BASE_URL` |
|---|---|
| `env/dev.json` | `http://10.0.2.2:8080` (host machine as seen from the Android emulator), plus per-service URLs for ports 8082 to 8085 |
| `env/prod.json` | production API, https://fcourt.donan.site |

| Define | Meaning |
|---|---|
| `APP_ENV` | `dev` (default) or `prod` |
| `API_BASE_URL` | Base URL of the gateway / API. Default `http://10.0.2.2:8080` |
| `AUTH_BASE_URL`, `SUBSCRIPTION_BASE_URL`, `DISCOVERY_BASE_URL`, `FACILITY_BASE_URL`, `STAFF_BASE_URL`, `POS_BASE_URL`, `REPORTING_BASE_URL`, `VOUCHER_BASE_URL` | Optional per-service overrides when there is no shared gateway; most fall back to `API_BASE_URL` |
| `SLOT_WEBSOCKET_URL` | Optional realtime slot WebSocket URL |
| `GOOGLE_WEB_CLIENT_ID` | OAuth Web client ID for Google sign-in (public value). Must equal `AUTH_GOOGLE_CLIENT_ID` of the auth service. The Android OAuth client uses package `com.bro73.fcourt` and the signing key SHA-1/SHA-256. |

## CI/CD

- `.github/workflows/ci.yml`: a `changes` job skips analyze/test for docs-only PRs; `analyze-and-test` runs `flutter analyze --fatal-infos --fatal-warnings` and `flutter test`; `android-build` builds a debug APK with a placeholder `google-services.json` when native files, dependencies or `env/` change. Required checks: `analyze-and-test`, `android-build`, `signing-smoke`, `changes`.
- `.github/workflows/flutter-build-android.yml` ("Android release"): signing smoke on Android/tooling PRs; on push to `main` it builds a signed APK and AAB and uploads them as Actions artifacts (kept 14 days). Nothing is published to a store automatically.
- Release signing guard: release builds fail without the external upload keystore; the debug key is never used. Inputs, secrets and verification are in [docs/release/android-release.md](docs/release/android-release.md).
- `.github/scripts/retry-on-network-error.sh` retries only download failures, never test or analyze failures.

## Testing

Run `flutter analyze` and `flutter test` before every PR (re-run after merging `dev`, since CI checks the merge result). The release signing tooling has Python tests in `tool/` (`python3 -m unittest discover -s tool -p 'test_*.py'`). Manual QA reports and per-task validation notes are in [docs/qa](docs/qa) and [docs/validation](docs/validation); fixture success is not live integration acceptance.

## Documentation

See [docs/README.md](docs/README.md): feature guides per Jira task, validation evidence, QA reports, release/signing and the execution plan.

## Contributing

- Branches: `main` (production), `dev` (integration), `feat/<name>`, `fix/<name>`, `docs/<name>`.
- Commits and PR titles are in English, `type(scope): message`, with the feature or area as scope (for example `fix(auth): handle expired refresh token`). Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.
- Open the PR into `dev` with at least one review and a green `analyze-and-test`. No direct pushes to `main` or `dev`.
- Do not commit secrets, tokens, `.env` files, keystores or `google-services.json`.
