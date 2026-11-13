import 'package:dio/dio.dart';
import 'package:fcourt/src/features/customer_slots/data/slot_remote_data_source.dart';
import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_options.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import 'slot_repository_test.dart' show row;

const publicRestriction = {
  'type': 'PRIVATE_EVENT',
  'publicReason': 'Giải đấu doanh nghiệp',
  'contactName': 'Bộ phận sự kiện',
  'contactPhone': '0901234567',
};

void main() {
  test(
    'bad optional metadata never unlocks a slot or exposes admin notes',
    () async {
      for (final metadata in <Object?>[
        null,
        'invalid',
        {'type': 'UNKNOWN'},
        {
          'type': 'PRIVATE_EVENT',
          'publicReason': 1,
          'contactName': 'x' * 101,
          'contactPhone': 'tel:javascript:bad',
          'notes': 'Internal secret',
        },
      ]) {
        final adapter = FakeAdapter(
          (_) => jsonResponse(200, [
            {
              ...row(1, '07:00', '07:30', status: 'OUT_OF_SERVICE'),
              'restriction': metadata,
            },
          ]),
        );
        final slot = (await SlotRemoteDataSource(
          Dio()..httpClientAdapter = adapter,
        ).getSlots(1, DateTime(2030))).single;
        expect(slot.status, SlotStatus.outOfService);
        expect(slot.restriction?.phoneUri, isNull);
        expect(slot.restriction?.publicReason, isNull);
        expect(slot.restriction?.contactName, isNull);
      }
    },
  );
  test('proposed metadata is optional and only describes actual out-of-service slots', () async {
    final adapter = FakeAdapter(
      (_) => jsonResponse(200, [
        {
          ...row(1, '07:00', '07:30', status: 'OUT_OF_SERVICE'),
          'restriction': publicRestriction,
        },
        row(2, '07:30', '08:00', status: 'OUT_OF_SERVICE'),
        {
          ...row(3, '08:00', '08:30', status: 'BOOKED'),
          'restriction': publicRestriction,
        },
        {...row(4, '08:30', '09:00'), 'restriction': publicRestriction},
      ]),
    );
    final slots = await SlotRemoteDataSource(Dio()..httpClientAdapter = adapter)
        .getSlots(1, DateTime(2030));
    expect(slots[0].status, SlotStatus.outOfService);
    expect(slots[0].displayLabel, 'Bao sân');
    expect(slots[0].restriction!.phoneUri.toString(), 'tel:0901234567');
    expect(slots[1].displayLabel, 'Ngừng phục vụ');
    expect(slots[2].displayLabel, 'Đã đặt');
    expect(slots[2].restriction, isNull);
    expect(slots[3].status, SlotStatus.available);
    expect(slots[3].restriction, isNull);
    expect(adapter.requests.single.extra['skipAuth'], isTrue);
  });
}
