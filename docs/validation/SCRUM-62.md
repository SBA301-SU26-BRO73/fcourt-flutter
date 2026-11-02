# SCRUM-62 slot-driven walk-in

Available court slots now appear on today's board. Only AVAILABLE cells open the
walk-in sheet; the canonical ID is reloaded and prefilled. If that slot became busy,
submission stays disabled. Consecutive count choices stop at busy cells/gaps.
Success immediately reloads schedule and availability, before receipt dismissal.

Recent-contact suggestions are bounded to 50, held only in the current board's
memory, isolated per branch, never written to disk or queried as unrestricted
customer lookup. Closing the board removes these suggestions.

2026-11-01: 40 tests pass in full Flutter suite. New widget cases verify tapped
slot prefill, recent contact fill, receipt, unavailable selection rejection and
disabled busy cells. Existing tests cover contiguous limits, conflicts, immutable
retry payloads/UUIDs and exact authoritative invoice validation. Analyze passes.

Read availability is not a reservation. Booking authority owns final concurrent
claim and invoice. Live red occupied-cell refresh and <20s Android operation must
be verified against that authority/on a device; fixture success is not signoff.
