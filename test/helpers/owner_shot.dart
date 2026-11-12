import 'dart:io';
import 'dart:ui' as ui;

import 'package:fcourt/app/theme/app_theme.dart';
import 'package:fcourt/app/widgets/wp3b_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screenshots of the owner screens for the mock-up comparison:
/// `WP3B_SHOTS=<dir> flutter test <file>` writes `<dir>/<name>-light.png` and
/// `-dark.png` (390x844 at 2x). Without the variable the tests only check the
/// layout.
final String? ownerShotDir = Platform.environment['WP3B_SHOTS'];

Future<void> loadOwnerFonts() async {
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

/// Owner tab bar as the shell draws it.
Widget ownerNavBar(int selected) => FloatingNavBar(
  selectedIndex: selected,
  onSelected: (_) {},
  items: const [
    FloatingNavItem(label: 'Việc cần làm', icon: Icons.task_alt_outlined),
    FloatingNavItem(label: 'Đơn', icon: Icons.receipt_long_outlined),
    FloatingNavItem(label: 'Chi nhánh', icon: Icons.storefront_outlined),
    FloatingNavItem(label: 'Tài khoản', icon: Icons.person_outline),
  ],
);

/// Pumps [screen] on a 390x844 phone (44dp status bar) inside the same kind
/// of Scaffold the shell uses, then writes the shot when asked. [withBack]
/// puts a route below the screen so its app bar shows the back button, as it
/// does when the screen is pushed.
Future<GlobalKey> pumpOwner(
  WidgetTester tester,
  Brightness brightness,
  Widget screen, {
  int navIndex = 0,
  bool nav = true,
  bool withBack = false,
  String? shot,
  Future<void> Function(WidgetTester)? before,
}) async {
  if (ownerShotDir != null) await loadOwnerFonts();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44);
  tester.view.viewPadding = const FakeViewPadding(top: 44);
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark
            ? AppTheme.dark()
            : AppTheme.light(),
        home: Scaffold(
          body: withBack
              ? Navigator(
                  onGenerateInitialRoutes: (_, _) => [
                    MaterialPageRoute<void>(
                      builder: (_) => const SizedBox.shrink(),
                    ),
                    MaterialPageRoute<void>(builder: (_) => screen),
                  ],
                )
              : screen,
          bottomNavigationBar: nav ? ownerNavBar(navIndex) : null,
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final e in tester.allElements.where(
      (e) => e.widget is Image && (e.widget as Image).image is AssetImage,
    )) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pumpAndSettle();
  if (before != null) await before(tester);
  // Photos that appeared after the first frame (loaded data) need a decode.
  await tester.runAsync(() async {
    for (final e in tester.allElements.where(
      (e) => e.widget is Image && (e.widget as Image).image is AssetImage,
    )) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pumpAndSettle();
  if (shot != null) await ownerShot(tester, key, shot, brightness);
  return key;
}

/// Writes `<dir>/<name>-<brightness>.png` when WP3B_SHOTS is set.
Future<void> ownerShot(
  WidgetTester tester,
  GlobalKey key,
  String name,
  Brightness brightness,
) async {
  if (ownerShotDir == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$ownerShotDir/$name-${brightness.name}.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}
