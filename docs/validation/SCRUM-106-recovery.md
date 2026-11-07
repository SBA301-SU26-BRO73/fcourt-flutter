# SCRUM-106: durable sale recovery

2026-11-06, Flutter 3.47.7 / Dart 3.13.5, Windows.

Before submitting a sale, the Android app persists the UUID, original quantities,
payment method, booking ID and display snapshot in secure storage. Reopening POS
restores an unresolved sale and locks cart edits until the employee explicitly
retries that exact command. Server idempotency supplies the original receipt.
Local snapshots never determine the final server price or stock.

Journals belong to the active account and cannot be overwritten by another
screen. Logout preserves unresolved sales for the original account. Corrupt or
unreadable storage blocks new sales. A failed write prevents HTTP submission;
a lost cleanup after server success retries the original UUID. Definitive
rejections clear the pending command; uncertain results retain it.

Validation: analyzer clean; all 598 tests pass, including 18 POS tests. New tests
cover screen recreation, immutable replay, account isolation, concurrent writers,
corrupt storage, write/cleanup failures and restored phone-cart interaction.

![Pending sale fixture](../review/screenshots/scrum106-pending.png)

Secure-storage persistence is exercised with the plugin's test implementation.
Hardware Keystore/process-kill acceptance remains an Android device check.
