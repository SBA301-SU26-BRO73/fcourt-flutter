import 'dart:io';
import 'dart:ui' as ui;

import 'package:fcourt/app/theme/app_theme.dart';
import 'package:fcourt/app/widgets/fc_widgets.dart';
import 'package:fcourt/app/widgets/wp3b_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shots: WP3B_SHOTS=`<dir>` flutter test test/app/wp3b_widgets_test.dart
final _dir = Platform.environment['WP3B_SHOTS'];

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

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

ThemeData _theme(Brightness b) =>
    b == Brightness.dark ? AppTheme.dark() : AppTheme.light();

Future<void> _pump(
  WidgetTester tester,
  Brightness b,
  Widget home, {
  GlobalKey? key,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(b),
        home: home,
      ),
    ),
  );
  // Decode bundled photos so the shot shows them.
  await tester.runAsync(() async {
    for (final e in tester.allElements.where((e) => e.widget is Image)) {
      final image = e.widget as Image;
      await precacheImage(image.image, e);
    }
  });
  await tester.pumpAndSettle();
}

class _Home extends StatelessWidget {
  const _Home();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            greeting: 'Chào buổi sáng, An',
            title: 'Hôm nay,\nmình chơi gì?',
            sportKind: SportKind.badminton,
            searchHint: 'Tìm sân, môn thể thao, khu vực',
            onSearchTap: () {},
            onFilterTap: () {},
            trailing: const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 23, 20, 0),
            child: Row(
              children: const [
                Expanded(
                  child: SportCircleIcon(
                    kind: SportKind.badminton,
                    label: 'Cầu lông',
                  ),
                ),
                Expanded(
                  child: SportCircleIcon(
                    kind: SportKind.pickleball,
                    label: 'Pickleball',
                  ),
                ),
                Expanded(
                  child: SportCircleIcon(
                    kind: SportKind.tennis,
                    label: 'Tennis',
                  ),
                ),
                Expanded(
                  child: SportCircleIcon(
                    kind: SportKind.football,
                    label: 'Bóng đá',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 23, 20, 15),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sân nổi bật',
                    style: t.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Xem tất cả',
                  style: t.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PhotoCard(
              title: 'Sân Cầu Lông Ba Đình',
              subtitle: '48 Văn Cao, Ba Đình, Hà Nội · 1,2 km',
              sport: 'Cầu lông',
              badge: '#1',
              priceText: 'Từ 50.000đ/giờ',
              ratingText: '4,6 (128)',
              onTap: () {},
            ),
          ),
          const SizedBox(height: FloatingNavBar.clearance),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: 0,
        onSelected: (_) {},
        items: const [
          FloatingNavItem(label: 'Khám phá', icon: Icons.explore_outlined),
          FloatingNavItem(
            label: 'Đơn của tôi',
            icon: Icons.confirmation_number_outlined,
          ),
          FloatingNavItem(
            label: 'Thông báo',
            icon: Icons.notifications_outlined,
            badgeCount: 2,
          ),
          FloatingNavItem(label: 'Tài khoản', icon: Icons.person_outline),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết chi nhánh')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          2,
          20,
          FloatingBottomBar.clearance,
        ),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: SizedBox(
              height: 304,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const SportPhoto(sport: 'Cầu lông'),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        CircleIconButton(
                          icon: Icons.chevron_left,
                          tooltip: 'Quay lại',
                          onImage: true,
                        ),
                        CircleIconButton(
                          icon: Icons.map_outlined,
                          tooltip: 'Bản đồ',
                          onImage: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Sân Cầu Lông Ba Đình',
            style: t.headlineSmall?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              TintTag('Đang mở cửa', tone: context.fc.success),
              TintTag('Chờ duyệt', tone: context.fc.warning),
              TintTag('Đã nhận sân', tone: context.fc.info),
              const TintTag('Cầu lông'),
              TintTag('Đã hủy', tone: context.fc.danger),
              TintTag('Hết lượt', tone: context.fc.neutral),
            ],
          ),
          const SizedBox(height: Gap.lg),
          const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: KpiCard(
                    label: 'Doanh thu hôm nay',
                    value: '12.400.000đ',
                    icon: Icons.payments_outlined,
                    note: '+12% so với hôm qua',
                  ),
                ),
                SizedBox(width: Gap.md),
                Expanded(
                  child: KpiCard(
                    label: 'Lượt đặt',
                    value: '48',
                    icon: Icons.event_available_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FloatingBottomBar(
        caption: 'Giá từ',
        priceText: '50.000đ/giờ',
        actionLabel: 'Đặt sân',
        onAction: () {},
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chọn giờ')),
    body: const SizedBox.expand(),
    bottomNavigationBar: FloatingBottomBar(
      filled: true,
      priceText: '07:00–09:00 · Sân 2 · 100.000đ',
      actionLabel: 'Tiếp tục',
      onAction: () {},
    ),
  );
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('home page: hero, sport icons, photo card, nav (${b.name})', (
      tester,
    ) async {
      if (_dir != null) await _fonts();
      final key = GlobalKey();
      await _pump(tester, b, const _Home(), key: key);
      expect(tester.takeException(), isNull);
      expect(find.byType(HeroHeader), findsOneWidget);
      expect(find.text('Hôm nay,\nmình chơi gì?'), findsOneWidget);
      expect(find.text('Cầu lông'), findsWidgets);
      expect(find.byType(FloatingNavBar), findsOneWidget);
      final hero = tester.getSize(find.byType(HeroHeader));
      expect(hero.height, 294);
      if (_dir != null) await _shot(tester, key, 'home-${b.name}');
    });

    testWidgets(
      'detail page: circle buttons, tags, kpi, bottom bar (${b.name})',
      (tester) async {
        if (_dir != null) await _fonts();
        final key = GlobalKey();
        await _pump(tester, b, const _Detail(), key: key);
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Quay lại'), findsOneWidget);
        expect(find.byType(TintTag), findsNWidgets(6));
        expect(find.byType(KpiCard), findsNWidgets(2));
        expect(find.text('Đặt sân'), findsOneWidget);
        if (_dir != null) await _shot(tester, key, 'detail-${b.name}');
      },
    );

    testWidgets('filled bottom bar and app bar back button (${b.name})', (
      tester,
    ) async {
      if (_dir != null) await _fonts();
      final key = GlobalKey();
      await _pump(tester, b, const _Picker(), key: key);
      expect(tester.takeException(), isNull);
      expect(find.text('Tiếp tục'), findsOneWidget);
      if (_dir != null) await _shot(tester, key, 'picker-${b.name}');
    });
  }

  testWidgets('photo card falls back to the sport photo and taps', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      Brightness.light,
      Scaffold(
        body: PhotoCard(
          title: 'Sân A',
          imageUrl: 'http://invalid.test/none.jpg',
          sport: 'Tennis',
          onTap: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('Sân A'));
    expect(taps, 1);
    // The test binding fails every HTTP request; the card shows the asset.
    expect(tester.takeException(), isA<NetworkImageLoadException>());
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is AssetImage),
      findsOneWidget,
    );
  });

  testWidgets('floating nav bar reports taps and shows the unread dot', (
    tester,
  ) async {
    int? picked;
    await _pump(
      tester,
      Brightness.dark,
      Scaffold(
        bottomNavigationBar: FloatingNavBar(
          selectedIndex: 0,
          onSelected: (i) => picked = i,
          items: const [
            FloatingNavItem(label: 'A', icon: Icons.home_outlined),
            FloatingNavItem(
              label: 'B',
              icon: Icons.notifications_outlined,
              badgeCount: 3,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('B'));
    expect(picked, 1);
    expect(find.byType(Badge), findsOneWidget);
  });

  test('sport image helper maps every sport to a bundled photo', () {
    for (final k in SportKind.values) {
      expect(File(SportImages.placeholder(k)).existsSync(), isTrue);
      expect(File(SportImages.hero(k)).existsSync(), isTrue);
    }
    expect(
      SportImages.placeholderFor('Cầu lông'),
      'assets/images/court-placeholder-badminton.webp',
    );
    expect(SportImages.heroFor('Bóng rổ'), 'assets/images/hero-football.webp');
  });
}
