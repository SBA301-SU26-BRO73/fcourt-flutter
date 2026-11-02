# SCRUM-64 weekly schedule

Day/week selector, Monday-based seven-day navigation, current week and date picker.
Weekly matrix preserves empty courts/days, selects one court, scrolls vertically
and horizontally and exposes full session details. Uses server lateCheckIn and
endingSoon flags; does not infer checkout or change authoritative state.

Ending-soon uses an amber surface, text warning and pulsing icon. Reduced-motion
setting stops the pulse. Quiet 30-second foreground polling refreshes the snapshot;
it pauses in background and behind modal/scanner routes. Stale requests cannot
replace a newer selected week. All timers/controllers are disposed.

2026-11-01: full Flutter suite 44 passed, analyze clean. New tests cover Monday
boundaries across months/years, exact range query, empty courts, flattened daily
response/flags, stale request ordering and two-axis 390px matrix with reduced
motion. Prior counter/admission regression tests remain green.

Not a live stream: freshness is bounded by polling and upstream latency. Android
scroll/jank performance, large production schedules and actual authority responses
remain acceptance checks. No native device or live backend accounts supplied.
