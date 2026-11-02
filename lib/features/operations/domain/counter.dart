class AvailableSlot {
  const AvailableSlot(
    this.id,
    this.start,
    this.end,
    this.price,
    this.available,
  );
  final int id;
  final String start;
  final String end;

  /// Minor currency units, never floating-point arithmetic.
  final int price;
  final bool available;
}

class CashReceipt {
  const CashReceipt(
    this.code,
    this.base,
    this.surcharge,
    this.total, {
    this.posAmount = 0,
  });
  final String code;
  final int base;
  final int surcharge;
  final int posAmount;
  final int total;
}

abstract class CounterRepository {
  Future<CashReceipt> checkoutPreview(int booking);
  Future<List<AvailableSlot>> slots(int court, String date);
  Future<CashReceipt> create(
    int court,
    String date,
    List<int> slots,
    String phone,
    String name,
    String key,
  );
  Future<void> checkout(
    int booking,
    String key, {
    required int expectedSurcharge,
    required int expectedTotal,
  });
}

List<AvailableSlot> contiguousSelection(
  List<AvailableSlot> slots,
  int start,
  int count,
) {
  if (count < 1 || count > 48 || start < 0 || start + count > slots.length) {
    return [];
  }
  final selected = slots.sublist(start, start + count);
  for (var i = 0; i < selected.length; i++) {
    if (!selected[i].available ||
        (i > 0 && selected[i - 1].end != selected[i].start)) {
      return [];
    }
  }
  return selected;
}

int parseMoney(Object? value) {
  final text = value.toString();
  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text)) {
    throw const FormatException('Invalid amount');
  }
  final parts = text.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}

String moneyLabel(int cents) {
  final units = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
  return '$units${cents % 100 == 0 ? '' : ',${(cents % 100).toString().padLeft(2, '0')}'} ₫';
}

String businessToday([DateTime? now]) => (now ?? DateTime.now())
    .toUtc()
    .add(const Duration(hours: 7))
    .toIso8601String()
    .substring(0, 10);
