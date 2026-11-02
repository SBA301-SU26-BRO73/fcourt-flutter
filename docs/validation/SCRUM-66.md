# SCRUM-66 manual admission

Keyboard action on schedule opens an autofocused, scrollable input dialog. Codes
uppercase and normalize printed hyphens; FC89234 becomes FC-89234. Other opaque
codes retain grouping. No booking-ID inference, URL fetching or raw-code logging.
Length/control-character validation and submit lock precede read-only preview.

Explicit confirmation uses MANUAL endpoint, stable retry UUID and existing
authoritative branch/date/state rules. Successful admission shows green icon and
customer/court/time, then closes input and refreshes the active day/week view.

2026-11-01: full Flutter suite 47 tests passes; analyze clean. New cases cover
normalization/bounds, keyboard focus, no write during preview, manual channel,
success details/close and unknown-code rejection. Regression also caught and fixed
a busy progress animation persisting behind the success dialog.

Device IME behavior and real unknown/foreign/already-used tickets still require
Android/live authority acceptance; API fixture success is not production signoff.
