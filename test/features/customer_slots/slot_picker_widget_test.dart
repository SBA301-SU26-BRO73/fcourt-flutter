import 'dart:io';
import 'dart:ui' as ui;

import 'package:fcourt/app/theme/app_theme.dart';
import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_options.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_repository.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_restriction.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'slot_test_support.dart';

final day = DateTime(2030, 1, 1);

void _noop(SlotSelection selection, String courtName) {}

Widget app(
  SlotRepository repository, {
  Brightness brightness = Brightness.light,
  List<PickerCourt> courts = const [court1, court2],
  void Function(SlotSelection, String)? onContinue = _noop,
  Key? boundary,
}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
  home: RepaintBoundary(
    key: boundary,
    child: SlotPickerScreen(
      repository: repository,
      courts: courts,
      branchName: 'Sân Cầu Lông Ba Đình',
      date: day,
      now: () => DateTime.utc(2029, 12, 31),
      onContinue: onContinue,
    ),
  ),
);

/// Builds the first frame, lets the fake repository answer and settles motion.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Day with a booked morning slot and a lunch break, like a real branch.
FakeSlots busyDay() => FakeSlots({
  1: daySlots(
    1,
    blocked: {
      8 * 60: SlotStatus.booked,
      8 * 60 + 30: SlotStatus.booked,
      18 * 60: SlotStatus.hold,
    },
  ),
  2: daySlots(2),
});

void main() {
  for (final brightness in Brightness.values) {
    group('${brightness.name} mode', () {
      testWidgets('shows day strip, courts, durations and grouped starts', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(app(busyDay(), brightness: brightness));
        await tester.pump();
        await settle(tester);
        expect(find.text('Chọn giờ'), findsOneWidget);
        expect(find.text('Sân Cầu Lông Ba Đình'), findsOneWidget);
        expect(find.text('Ngày chơi'), findsOneWidget);
        expect(find.text('Tất cả sân'), findsOneWidget);
        expect(find.text('Sân 2'), findsOneWidget);
        for (final label in ['1 giờ', '1,5 giờ', '2 giờ']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('Sáng'), findsOneWidget);
        expect(find.text('Chưa chọn giờ'), findsOneWidget);
        expect(find.text('Còn Sân 1, Sân 2'), findsWidgets);
        // 08:00 is booked on court 1 only, so court 2 is the only one left.
        expect(find.text('Còn Sân 2'), findsWidgets);
      });

      testWidgets(
        'two-hour game takes three taps and hands over court + slots',
        (tester) async {
          phone(tester);
          SlotSelection? picked;
          String? courtName;
          await tester.pumpWidget(
            app(
              busyDay(),
              brightness: brightness,
              onContinue: (selection, name) {
                picked = selection;
                courtName = name;
              },
            ),
          );
          await settle(tester);
          InkWell continueButton() => tester.widget<InkWell>(
            find.ancestor(
              of: find.text('Tiếp tục'),
              matching: find.byType(InkWell),
            ),
          );
          expect(continueButton().onTap, isNull);
          await tester.tap(find.text('2 giờ')); // tap 1
          await settle(tester);
          await tester.tap(find.text('07:00–09:00')); // tap 2
          await settle(tester);
          expect(find.textContaining('gợi ý Sân 2'), findsOneWidget);
          expect(find.textContaining('100.000đ'), findsWidgets);
          await tester.tap(find.text('Tiếp tục')); // tap 3
          expect(courtName, 'Sân 2', reason: 'court 1 is booked at 08:00');
          expect(picked!.courtId, 2);
          expect(picked!.slots.length, 4);
          expect(picked!.totalMinor, 4 * 2500000);
        },
      );

      testWidgets('court chip narrows the list and clears the selection', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(app(busyDay(), brightness: brightness));
        await settle(tester);
        await tester.tap(find.text('07:00–08:00'));
        await settle(tester);
        expect(find.textContaining('gợi ý'), findsOneWidget);
        await tester.tap(find.text('Sân 2'));
        await settle(tester);
        expect(find.text('Chưa chọn giờ'), findsOneWidget);
        expect(find.text('Còn Sân 1, Sân 2'), findsNothing);
      });

      testWidgets('blocked starts are hidden until the switch is on', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(app(busyDay(), brightness: brightness));
        await settle(tester);
        await tester.tap(find.text('Sân 1'));
        await settle(tester);
        expect(find.text('08:00–09:00'), findsNothing);
        await tester.tap(find.text('Hiện giờ đã đặt / đã qua'));
        await settle(tester);
        expect(find.text('08:00–09:00'), findsOneWidget);
        expect(find.text('Đã đặt'), findsWidgets);
        await tester.tap(find.text('08:00–09:00'));
        await settle(tester);
        expect(find.text('Chưa chọn giờ'), findsOneWidget);
      });

      testWidgets('empty day offers Xem ngày khác', (tester) async {
        phone(tester);
        final repository = FakeSlots({
          1: daySlots(1, to: 8 * 60),
          2: daySlots(2, to: 8 * 60),
        });
        await tester.pumpWidget(app(repository, brightness: brightness));
        await settle(tester);
        await tester.tap(find.text('2 giờ'));
        await settle(tester);
        expect(find.text('Không còn giờ trống'), findsOneWidget);
        repository.calls.clear();
        await tester.tap(find.text('Xem ngày khác'));
        await settle(tester);
        expect(repository.calls.toSet(), {1, 2});
      });
    });
  }

  testWidgets('single court hides the court chips', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      app(FakeSlots({1: daySlots(1)}), courts: const [court1]),
    );
    await settle(tester);
    expect(find.text('SÂN'), findsNothing);
    expect(find.text('Tất cả sân'), findsNothing);
    expect(find.text('Còn trống'), findsWidgets);
  });

  testWidgets('skeleton shows while loading and touch targets are 48dp', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(busyDay()));
    expect(find.bySemanticsLabel('Đang tải giờ trống'), findsOneWidget);
    await settle(tester);
    for (final label in ['Tất cả sân', '1 giờ']) {
      final pill = find.ancestor(
        of: find.text(label),
        matching: find.byType(GestureDetector),
      );
      expect(tester.getSize(pill.first).height, greaterThanOrEqualTo(48));
    }
    final tile = find.ancestor(
      of: find.text('07:00–08:00'),
      matching: find.byType(AnimatedContainer),
    );
    expect(tester.getSize(tile.first).height, greaterThanOrEqualTo(64));
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.text('Tiếp tục'),
              matching: find.byType(InkWell),
            ),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('private event lock shows contact card and stays unselectable', (
    tester,
  ) async {
    phone(tester);
    const contact = SlotRestriction(
      isPrivateEvent: true,
      contactName: 'Bộ phận sự kiện',
      contactPhone: '0901234567',
    );
    final slots = [
      for (final s in daySlots(1, to: 10 * 60))
        s.startMinute < 8 * 60
            ? CourtSlot(
                id: s.id,
                startMinute: s.startMinute,
                endMinute: s.endMinute,
                priceMinor: s.priceMinor,
                status: SlotStatus.outOfService,
                restriction: contact,
              )
            : s,
    ];
    await tester.pumpWidget(app(FakeSlots({1: slots}), courts: const [court1]));
    await settle(tester);
    expect(find.text('Liên hệ sự kiện'), findsOneWidget);
    await tester.tap(find.text('Hiện giờ đã đặt / đã qua'));
    await settle(tester);
    expect(find.text('Bao sân'), findsWidgets);
    await tester.tap(find.text('07:00–08:00'));
    await settle(tester);
    expect(find.text('Chưa chọn giờ'), findsOneWidget);
  });

  // Screenshots for the PR: SLOT_PICKER_SHOTS=<dir> flutter test <this file>.
  final shotDir = Platform.environment['SLOT_PICKER_SHOTS'];
  testWidgets('preview screenshots (light and dark)', skip: shotDir == null, (
    tester,
  ) async {
    phone(tester);
    await _loadFonts();
    for (final brightness in Brightness.values) {
      Future<GlobalKey> mount(SlotRepository repository) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          app(repository, brightness: brightness, boundary: key),
        );
        return key;
      }

      String file(String name) =>
          '$shotDir/slot-picker-${brightness.name}-$name.png';

      var key = await mount(busyDay());
      await settle(tester);
      await _shot(tester, key, file('1-start'));
      await tester.tap(find.text('2 giờ'));
      await settle(tester);
      await tester.tap(find.text('07:00–09:00'));
      await settle(tester);
      await _shot(tester, key, file('2-selected'));
      await tester.tap(find.text('Sân 1'));
      await settle(tester);
      await tester.tap(find.text('Hiện giờ đã đặt / đã qua'));
      await settle(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -330));
      await settle(tester);
      await _shot(tester, key, file('3-show-booked'));
      key = await mount(
        FakeSlots({1: daySlots(1, to: 8 * 60), 2: daySlots(2, to: 8 * 60)}),
      );
      await settle(tester);
      await tester.tap(find.text('2 giờ'));
      await settle(tester);
      await _shot(tester, key, file('4-no-slots'));
      key = await mount(PendingSlots());
      await tester.pump(const Duration(milliseconds: 100));
      await _shot(tester, key, file('5-skeleton'));
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
  }
  final loader = FontLoader('PlusJakartaSans');
  for (final name in ['Regular', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/PlusJakartaSans-$name.ttf')
        .readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
    );
  }
  await loader.load();
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}
