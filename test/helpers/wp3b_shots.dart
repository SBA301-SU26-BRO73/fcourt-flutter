import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fcourt/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shots: WP3B_SHOTS=`<dir>` flutter test <file>. Without it the helpers only
/// pump the page (so the test is a plain smoke test in CI).
final shotsDir = Platform.environment['WP3B_SHOTS'];

Future<void> loadShotFonts() async {
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
