import 'dart:io';
import 'dart:ui' as ui;

import 'package:fcourt/app/theme/app_theme.dart';
import 'package:fcourt/app/widgets/fc_widgets.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_status.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_detail.dart';
import 'package:fcourt/features/admin_dashboard/domain/entities/analytics.dart';
import 'package:fcourt/features/admin_dashboard/domain/entities/dashboard_stats.dart';
import 'package:fcourt/features/admin_dashboard/presentation/pages/admin_dashboard_screen.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/booking_status_pie_chart.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/occupancy_gauge.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/revenue_line_chart.dart';
import 'package:fcourt/features/admin_facility/domain/entities/court.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/branch_list_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/court_list_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/widgets/day_of_week_chips.dart';
import 'package:fcourt/features/vouchers/domain/voucher.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_facility/fixtures.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + .05) / (lo + .05);
}

Future<void> _fonts() async {
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
  final loader = FontLoader('BeVietnamPro');
  for (final name in ['Regular', 'Medium', 'Bold']) {
    final bytes = File('assets/fonts/BeVietnamPro-$name.ttf').readAsBytesSync();
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

Widget _list(List<Widget> children, {Widget? fab, String title = ''}) =>
    Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: fab,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.sm,
          Gap.screen,
          Gap.fabClearance,
        ),
        children: [
          for (final c in children)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: c,
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            label: 'Chi nhánh',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Tài khoản',
          ),
        ],
      ),
    );

final _revenue = RevenueChart(
  granularity: RevenueGranularity.day,
  from: DateTime(2026, 11, 1),
  to: DateTime(2026, 11, 7),
  totalRevenue: 75300000,
  totalBookings: 369,
  occupancyRate: .42,
  points: [
    for (var i = 0; i < 7; i++)
      RevenuePoint(
        periodStart: DateTime(2026, 11, 1 + i),
        periodEnd: DateTime(2026, 11, 1 + i),
        revenue: [4, 9, 6, 12, 8, 11, 7][i] * 1000000,
        bookings: 10 + i,
        occupancyRate: .4,
      ),
  ],
);

AdminBooking _booking() => AdminBooking(
  id: 1,
  code: 'BK2941',
  branchId: 1,
  branchName: 'FCourt Quận 7',
  courtId: 5,
  courtName: 'Sân 5',
  date: DateTime(2026, 11, 13),
  createdAt: DateTime.utc(2026, 11, 12, 3),
  status: AdminBookingStatus.awaitingConfirmation,
  amount: 240000,
  customerName: 'Nguyễn Thị Lan',
  customerPhone: '0901234567',
  paymentStatus: 'PENDING',
);

Voucher _voucher(int i, DateTime end, int used) => Voucher(
  id: i,
  branchId: 1,
  code: 'TET2026-$i',
  type: VoucherDiscountType.percentage,
  valueMinor: 1500,
  capMinor: 5000000,
  minOrderMinor: 10000000,
  startsAt: DateTime.utc(2026, 11, 1),
  endsAt: end,
  limit: 100,
  usedCount: used,
  status: VoucherStatus.active,
);

void main() {
  // Screenshots: OWNER_SHOTS=<dir> flutter test test/features/owner_admin_gallery_test.dart
  final dir = Platform.environment['OWNER_SHOTS'];

  testWidgets('pie chart slice labels reach AA contrast', (tester) async {
    for (final c in [
      BookingStatusPieChart.confirmedColor,
      BookingStatusPieChart.pendingColor,
      BookingStatusPieChart.cancelledColor,
    ]) {
      expect(
        _ratio(BookingStatusPieChart.sliceLabelColor(c), c),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets('owner and admin screens render in light and dark', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _fonts();
    final now = DateTime.utc(2026, 11, 12, 5);
    final pages = <String, Widget Function()>{
      'dashboard': () => _list(title: 'Tổng quan', [
        Row(
          children: [
            const Expanded(
              child: SizedBox(
                height: 132,
                child: StatCard(
                  icon: Icons.payments_outlined,
                  color: ChartColors.success,
                  label: 'Tổng doanh thu',
                  value: '75.3M đ',
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            const Expanded(
              child: SizedBox(
                height: 132,
                child: StatCard(
                  icon: Icons.donut_large,
                  color: ChartColors.peak,
                  label: 'Tỷ lệ lấp đầy',
                  value: '42%',
                ),
              ),
            ),
          ],
        ),
        const FcCard(
          child: BookingStatusPieChart(
            counts: BookingStatusCounts(
              confirmed: 280,
              pending: 31,
              cancelled: 58,
            ),
          ),
        ),
      ]),
      'analytics': () => _list(title: 'Phân tích', [
        FcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Doanh thu'),
              const SizedBox(height: Gap.md),
              const Text('Tổng 75.3M đ · 369 lượt đặt'),
              const SizedBox(height: Gap.lg),
              RevenueLineChart(chart: _revenue),
            ],
          ),
        ),
        const FcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tỷ lệ lấp đầy'),
              SizedBox(height: Gap.md),
              OccupancyGauge(rate: .42),
            ],
          ),
        ),
      ]),
      'branches': () => _list(
        title: 'Chi nhánh của tôi',
        fab: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Thêm chi nhánh'),
        ),
        [
          for (final i in [1, 2, 3])
            BranchCard(
              branch: sampleBranch(id: i, name: 'FCourt Quận $i'),
              onTap: () {},
              onEdit: () {},
              onImages: () {},
              onPayments: () {},
              onRefunds: () {},
              onTransactions: () {},
            ),
        ],
      ),
      'courts': () => _list(
        title: 'Quản lý sân',
        fab: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Thêm sân'),
        ),
        [
          for (final (i, s) in [
            CourtStatus.active,
            CourtStatus.maintenance,
            CourtStatus.active,
          ].indexed)
            SizedBox(
              height: 200,
              child: CourtCard(
                court: sampleCourt(id: i + 1, status: s),
                typeName: 'Cầu lông',
                updating: false,
                onTap: () {},
                onSlotTemplate: () {},
                onCalendar: () {},
                onPricing: () {},
                onMaintenanceChanged: (_) {},
              ),
            ),
        ],
      ),
      'vouchers': () => _list(
        title: 'Quản lý voucher',
        fab: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Tạo voucher'),
        ),
        [
          VoucherCard(
            voucher: _voucher(1, DateTime.utc(2026, 12, 31), 12),
            now: now,
            busy: false,
            onEdit: () {},
            onEnabled: (_) {},
          ),
          VoucherCard(
            voucher: _voucher(2, DateTime.utc(2026, 11, 5), 100),
            now: now,
            busy: false,
            onEdit: () {},
            onEnabled: (_) {},
          ),
        ],
      ),
      'day-chips': () => _list(title: 'Áp dụng mẫu', [
        FcCard(
          child: DayOfWeekChips(
            selected: const {1, 2, 3, 4, 5},
            onToggle: (_) {},
          ),
        ),
      ]),
      'booking-detail': () =>
          AdminBookingDetail(booking: _booking(), onReviewPayment: () {}),
    };
    for (final entry in pages.entries) {
      for (final b in Brightness.values) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: b == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
              home: entry.value(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: entry.key);
        if (dir != null) {
          await _shot(tester, key, '$dir/${entry.key}-${b.name}.png');
        }
      }
    }
  });
}
