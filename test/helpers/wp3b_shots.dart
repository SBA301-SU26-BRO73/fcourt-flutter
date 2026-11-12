import 'dart:io';
import 'dart:ui' as ui;

import 'package:fcourt/app/theme/app_theme.dart';
import 'package:fcourt/app/widgets/wp3b_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shots: WP3B_SHOTS=`<dir>` flutter test `<test>` writes one PNG per screen.
final wp3bShotDir = Platform.environment['WP3B_SHOTS'];

Future<void> wp3bLoadFonts() async {
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

ThemeData wp3bTheme(Brightness b) =>
    b == Brightness.dark ? AppTheme.dark() : AppTheme.light();

/// 390x844 phone with a 44dp status bar and a 15dp gesture inset.
void wp3bPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 15);
  tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 15);
  addTearDown(tester.view.reset);
}

Future<void> wp3bPrecache(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in tester.allElements.where((e) => e.widget is Image)) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
}

Future<void> wp3bShot(WidgetTester tester, GlobalKey key, String name) async {
  final dir = wp3bShotDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// Mounts [home] under the real theme, in a 390x844 phone, and waits for the
/// bundled photos to decode.
Future<GlobalKey> wp3bPump(
  WidgetTester tester,
  Brightness b,
  Widget home, {
  RouterConfig<Object>? router,
  bool back = false,
}) async {
  wp3bPhone(tester);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: router != null
          ? MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: wp3bTheme(b),
              routerConfig: router,
            )
          : MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: wp3bTheme(b),
              // Two routes so the app bar shows its back button.
              initialRoute: back ? '/x' : null,
              onGenerateInitialRoutes: back
                  ? (_) => [
                      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
                      MaterialPageRoute<void>(builder: (_) => home),
                    ]
                  : null,
              home: back ? null : home,
              onGenerateRoute: back
                  ? (_) => MaterialPageRoute<void>(builder: (_) => home)
                  : null,
            ),
    ),
  );
  await tester.pump();
  await wp3bPrecache(tester);
  await tester.pumpAndSettle();
  return key;
}

/// The customer tab bar of the shell, for screens that live in a tab.
Widget wp3bShell(Widget body, {required int selected}) => Scaffold(
  extendBody: true,
  body: body,
  bottomNavigationBar: FloatingNavBar(
    selectedIndex: selected,
    onSelected: (_) {},
    items: const [
      FloatingNavItem(label: 'Khám phá', icon: Icons.home_outlined),
      FloatingNavItem(
        label: 'Đơn của tôi',
        icon: Icons.event_available_outlined,
      ),
      FloatingNavItem(label: 'Thông báo', icon: Icons.notifications_outlined),
      FloatingNavItem(label: 'Tài khoản', icon: Icons.person_outline),
    ],
  ),
);

/// A PNG that looks like a QR code (finder squares plus noisy modules), for
/// shots of screens that show the entry ticket.
Future<Uint8List> wp3bFakeQrPng(WidgetTester tester) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    const n = 29, cell = 8.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final white = Paint()..color = Colors.white;
    final black = Paint()..color = const Color(0xFF111827);
    canvas.drawRect(const Rect.fromLTWH(0, 0, n * cell, n * cell), white);
    bool finder(int x, int y) =>
        (x < 8 && y < 8) || (x > n - 9 && y < 8) || (x < 8 && y > n - 9);
    var seed = 7;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        if (!finder(x, y) && (seed >> 16) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), black);
        }
      }
    }
    for (final o in const [Offset(0, 0), Offset(n - 7, 0), Offset(0, n - 7)]) {
      final r = Rect.fromLTWH(o.dx * cell, o.dy * cell, 7 * cell, 7 * cell);
      canvas.drawRect(r, black);
      canvas.drawRect(r.deflate(cell), white);
      canvas.drawRect(r.deflate(2 * cell), black);
    }
    final image = await recorder.endRecording().toImage(
      (n * cell).toInt(),
      (n * cell).toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
  });
  return bytes;
}

/// Shots: `WP3B_SHOTS=<dir> flutter test <file>`. Without it the helpers only
/// pump the page (so the test is a plain smoke test in CI).
final shotsDir = Platform.environment['WP3B_SHOTS'];

Future<void> loadShotFonts() => wp3bLoadFonts();

ThemeData shotTheme(Brightness b) =>
    b == Brightness.dark ? AppTheme.dark() : AppTheme.light();

/// Pumps [home] at 390x844 and, when WP3B_SHOTS is set, writes
/// `<dir>/<name>-<light|dark>.png`.
Future<void> pumpShot(
  WidgetTester tester,
  Brightness b,
  Widget home, {
  required String name,
  Size size = const Size(390, 844),
  Widget Function(Widget child)? wrap,
  Future<void> Function(WidgetTester tester)? prepare,
}) async {
  final key = GlobalKey();
  if (shotsDir != null) await loadShotFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: shotTheme(b),
        home: wrap == null ? home : wrap(home),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final e in tester.allElements.where((e) => e.widget is Image)) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pumpAndSettle();
  if (prepare != null) {
    await prepare(tester);
    await tester.pumpAndSettle();
  }
  if (shotsDir == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$shotsDir/$name-${b.name}.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}
