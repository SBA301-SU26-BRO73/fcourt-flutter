/// Parses same-day booking slots; midnight is the end of the play day.
List<String> bookingSlotTimes(dynamic raw) {
  if (raw is! List || raw.length > 48) throw const FormatException();
  final pattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$');
  int seconds(String value) =>
      int.parse(value.substring(0, 2)) * 3600 +
      int.parse(value.substring(3, 5)) * 60 +
      (value.length == 8 ? int.parse(value.substring(6, 8)) : 0);
  final ranges = raw.map((slot) {
    if (slot is! Map) throw const FormatException();
    final start = slot['startTime'], end = slot['endTime'];
    if (start is! String ||
        end is! String ||
        !pattern.hasMatch(start) ||
        !pattern.hasMatch(end)) {
      throw const FormatException();
    }
    final from = seconds(start);
    final to = seconds(end) == 0 ? 86400 : seconds(end);
    if (from == seconds(end) || from >= to) throw const FormatException();
    return (
      from: from,
      to: to,
      label: '${start.substring(0, 5)}–${end.substring(0, 5)}',
    );
  }).toList()..sort((a, b) => a.from.compareTo(b.from));
  for (var i = 1; i < ranges.length; i++) {
    if (ranges[i].from < ranges[i - 1].to) throw const FormatException();
  }
  return ranges.map((range) => range.label).toList();
}
