# SCRUM-29 validation

Today schedule uses assigned branch; read-only ticket preview is separate from
the idempotent confirmation command. Only authoritative CHECKED_IN with matching
booking ID yields success. QR text is opaque, bounded and never fetched as a URL.
Camera stops during dialogs/background, supports torch/haptics and permission
recovery; CAMERA is optional hardware for manual fallback.

Automated: full Flutter suite, static analysis, HTTP projection/channel/key tests,
explicit-confirm widget test, network retry with original UUID, schedule refresh
failure preserving prior data. Backend preview has HTTP/JWT/PostgreSQL tests
proving preview does not mutate commands/check-in and rejects branch mismatch.
Exact test counts/check results are recorded in the task PR.

Requires the booking authority read-only preview contract in backend support PR.
No real gateway or test accounts supplied. No Android SDK/device available:
permission prompts, native camera lifecycle, dark-scene QR speed (<500ms), flash
hardware and haptics remain device acceptance checks. Automated HTTP/widget
tests cannot establish those targets. Do not claim production/device acceptance.
