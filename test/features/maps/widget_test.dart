import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:fcourt/features/maps/domain/branch_location.dart';
import 'package:fcourt/features/maps/presentation/branch_map_card.dart';
import 'package:fcourt/features/maps/presentation/google_branch_map.dart';
import 'package:fcourt/features/maps/presentation/open_street_branch_map.dart';

class Maps implements BranchMapPlatform {
  BranchMapAvailability state = BranchMapAvailability.unavailable;
  Completer<BranchMapAvailability>? pending;
  Completer<bool>? opening;
  int probes = 0, directionsCalls = 0, attributionCalls = 0;
  BranchLocation? destination;
  @override
  Future<BranchMapAvailability> availability() async {
    probes++;
    return pending?.future ?? state;
  }

  @override
  Future<bool> directions(BranchLocation location) async {
    directionsCalls++;
    destination = location;
    return opening?.future ?? true;
  }

  @override
  Future<bool> openStreetMap(BranchLocation location) async => true;
  @override
  Future<bool> attribution() async {
    attributionCalls++;
    return true;
  }
}

class Tiles extends TileProvider {
  final image = MemoryImage(
    File('test/fixtures/payment_ticket.png').readAsBytesSync(),
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      image;
}

class ContextStub extends Fake implements BuildContext {}

void main() {
  final location = BranchLocation.parse(10.123456, 106.654321)!;
  Widget card(
    Maps maps, {
    BranchLocation? point,
    String name = 'Sân A',
    NativeBranchMapBuilder? native,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BranchMapCard(
          location: point ?? location,
          name: name,
          platform: maps,
          nativeBuilder: native,
          fallbackBuilder: (_, name) =>
              SizedBox(height: 260, child: Text('OSM:$name')),
        ),
      ),
    ),
  );

  test('native renderer centers exact GPS and exposes branch name in marker info window', () {
    final map = GoogleBranchMap(
      location: location,
      name: 'Sân A',
      onReady: () {},
    ).build(ContextStub()) as google.GoogleMap;
    expect(map.initialCameraPosition.target.latitude, location.latitude);
    expect(map.initialCameraPosition.target.longitude, location.longitude);
    expect(map.markers.single.position, map.initialCameraPosition.target);
    expect(map.markers.single.infoWindow.title, 'Sân A');
    expect(map.myLocationEnabled, isFalse);
    expect(map.myLocationButtonEnabled, isFalse);
  });
  testWidgets('missing GPS never probes native service or fabricates marker', (
    tester,
  ) async {
    final maps = Maps();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BranchMapCard(location: null, name: 'Sân A', platform: maps),
        ),
      ),
    );
    expect(find.text('Chi nhánh chưa có tọa độ GPS hợp lệ.'), findsOneWidget);
    expect(find.text('Chỉ đường đến sân'), findsNothing);
    expect(maps.probes, 0);
  });
  testWidgets(
    'missing Play Services or key selects OSM with visible attribution',
    (tester) async {
      for (final state in [
        BranchMapAvailability.missingKey,
        BranchMapAvailability.unavailable,
      ]) {
        final maps = Maps()..state = state;
        await tester.pumpWidget(card(maps));
        await tester.pumpAndSettle();
        expect(find.text('OSM:Sân A'), findsOneWidget);
        expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
        await tester.tap(find.text('© OpenStreetMap contributors'));
        await tester.pumpAndSettle();
        expect(maps.attributionCalls, 1);
      }
    },
  );
  testWidgets('native ready view supports manual OSM fallback', (tester) async {
    final maps = Maps()..state = BranchMapAvailability.available;
    VoidCallback? ready;
    await tester.pumpWidget(
      card(
        maps,
        native: (_, name, callback) {
          ready = callback;
          return Text('Google:$name');
        },
      ),
    );
    await tester.pump();
    ready!();
    await tester.pumpAndSettle();
    expect(find.text('Google:Sân A'), findsOneWidget);
    await tester.tap(find.text('Xem bản đồ dự phòng'));
    await tester.pumpAndSettle();
    expect(find.text('OSM:Sân A'), findsOneWidget);
  });
  testWidgets(
    'native creation timeout recovers with OSM instead of indefinite spinner',
    (tester) async {
      final maps = Maps()..state = BranchMapAvailability.available;
      await tester.pumpWidget(
        card(maps, native: (_, _, _) => const Text('Native loading')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 13));
      await tester.pumpAndSettle();
      expect(find.text('OSM:Sân A'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('late availability result cannot replace timed out fallback', (
    tester,
  ) async {
    final maps = Maps()..pending = Completer<BranchMapAvailability>();
    await tester.pumpWidget(card(maps));
    await tester.pump(const Duration(seconds: 6));
    maps.pending!.complete(BranchMapAvailability.available);
    await tester.pumpAndSettle();
    expect(find.text('OSM:Sân A'), findsOneWidget);
  });
  testWidgets(
    'old branch native ready callback cannot cancel the new branch timeout',
    (tester) async {
      final maps = Maps()..state = BranchMapAvailability.available;
      final callbacks = <VoidCallback>[];
      Widget build(String name, BranchLocation point) => card(
        maps,
        name: name,
        point: point,
        native: (_, name, ready) {
          callbacks.add(ready);
          return Text('Google:$name');
        },
      );
      await tester.pumpWidget(build('Sân A', location));
      await tester.pump();
      final old = callbacks.last;
      await tester.pumpWidget(build('Sân B', BranchLocation.parse(11, 107)!));
      await tester.pump();
      old();
      await tester.pump(const Duration(seconds: 13));
      await tester.pumpAndSettle();
      expect(find.text('OSM:Sân B'), findsOneWidget);
    },
  );
  testWidgets(
    'directions disables repeated taps while launch pending and explains failure',
    (tester) async {
      final maps = Maps()..opening = Completer<bool>();
      await tester.pumpWidget(card(maps));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chỉ đường đến sân'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Chỉ đường đến sân'),
            )
            .onPressed,
        isNull,
      );
      expect(maps.directionsCalls, 1);
      expect(maps.destination!.coordinates, location.coordinates);
      maps.opening!.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa mở được bản đồ. Vui lòng thử lại.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'fallback keeps GPS marker and app user agent on narrow large text layout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tiles = Tiles();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: SizedBox(
                height: 260,
                child: OpenStreetBranchMap(
                  location: location,
                  name: 'Sân thể thao với tên rất dài dành cho khách hàng đến chơi tại chi nhánh',
                  tileProvider: tiles,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final marker = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .single;
      expect(marker.point.latitude, location.latitude);
      expect(marker.point.longitude, location.longitude);
      expect(tiles.headers['User-Agent'], contains('com.bro73.fcourt'));
      expect(
        tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
