import 'package:fcourt/features/admin_facility/domain/entities/branch_rules.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/slot_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BranchRules', () {
    test('giờ đóng cửa phải sau giờ mở cửa', () {
      expect(
        BranchRules.timeRange(const ClockTime(6, 0), const ClockTime(22, 0)),
        isNull,
      );
      expect(
        BranchRules.timeRange(const ClockTime(22, 0), const ClockTime(6, 0)),
        'Giờ đóng cửa phải sau giờ mở cửa',
      );
      expect(
        BranchRules.timeRange(const ClockTime(8, 0), const ClockTime(8, 0)),
        isNotNull,
      );
    });

    test('số tài khoản 6–20 chữ số', () {
      expect(BranchRules.accountNumber('123456'), isNull);
      expect(BranchRules.accountNumber('1' * 20), isNull);
      expect(BranchRules.accountNumber('12345'), isNotNull);
      expect(BranchRules.accountNumber('1' * 21), isNotNull);
      expect(BranchRules.accountNumber('12345a7'), isNotNull);
      expect(BranchRules.accountNumber(''), 'Vui lòng nhập số tài khoản');
    });

    test('BIN ngân hàng đúng 6 chữ số', () {
      expect(BranchRules.bankBin('970436'), isNull);
      expect(BranchRules.bankBin('97043'), isNotNull);
      expect(BranchRules.bankBin(null), isNotNull);
    });

    test('số điện thoại tùy chọn nhưng phải hợp lệ nếu có', () {
      expect(BranchRules.phone(''), isNull);
      expect(BranchRules.phone('0901234567'), isNull);
      expect(BranchRules.phone('12345'), isNotNull);
    });
  });

  group('generateSlotMatrix', () {
    test('sinh slot 30 phút liên tiếp 06:00–06:30, 06:30–07:00...', () {
      final slots = generateSlotMatrix(
        start: const ClockTime(6, 0),
        end: const ClockTime(8, 0),
        price: 60000,
      );

      expect(slots.map((s) => '${s.startTime}-${s.endTime}'), [
        '06:00-06:30',
        '06:30-07:00',
        '07:00-07:30',
        '07:30-08:00',
      ]);
      expect(slots.every((s) => s.price == 60000), isTrue);
    });

    test('cả ngày không vượt quá 48 slot', () {
      final slots = generateSlotMatrix(
        start: const ClockTime(0, 0),
        end: const ClockTime(23, 30),
        price: 1,
      );

      expect(maxSlotsPerDay, 48);
      expect(slots, hasLength(47));
      expect(slots.length, lessThanOrEqualTo(maxSlotsPerDay));
      expect(slots.last.endTime, const ClockTime(23, 30));
    });

    test('giờ kết thúc trước giờ bắt đầu hoặc lệch bước → rỗng', () {
      expect(
        generateSlotMatrix(
          start: const ClockTime(22, 0),
          end: const ClockTime(6, 0),
          price: 1,
        ),
        isEmpty,
      );
      expect(
        generateSlotMatrix(
          start: const ClockTime(6, 0),
          end: const ClockTime(6, 45),
          price: 1,
        ),
        isEmpty,
      );
    });

    test('validateSlotRange theo quy tắc backend', () {
      const open = ClockTime(6, 0);
      const close = ClockTime(22, 0);
      expect(
        validateSlotRange(
          start: const ClockTime(7, 0),
          end: const ClockTime(6, 0),
        ),
        SlotRangeIssue.endNotAfterStart,
      );
      expect(
        validateSlotRange(
          start: const ClockTime(5, 30),
          end: const ClockTime(8, 0),
          branchOpen: open,
          branchClose: close,
        ),
        SlotRangeIssue.outsideBranchHours,
      );
      expect(
        validateSlotRange(
          start: const ClockTime(6, 0),
          end: const ClockTime(7, 15),
          branchOpen: open,
          branchClose: close,
        ),
        SlotRangeIssue.notDivisible,
      );
      expect(
        validateSlotRange(
          start: open,
          end: close,
          branchOpen: open,
          branchClose: close,
        ),
        isNull,
      );
    });

    test('giá slot mặc định = giá giờ * 30/60', () {
      expect(defaultSlotPrice(120000), 60000);
      expect(defaultSlotPrice(95000), 47500);
    });
  });
}
