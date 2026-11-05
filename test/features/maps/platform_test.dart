import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/features/maps/domain/branch_location.dart';
import 'package:fcourt/features/maps/data/device_branch_map_platform.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_remote_data_source.dart';
import 'package:dio/dio.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.bro73.fcourt/maps');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('coordinate pairs reject absent malformed nonfinite and out of range values', () {
    for (final pair in <List<Object?>>[
      [null, null],
      [10, null],
      [null, 106],
      ['10', 106],
      [double.nan, 106],
      [10, double.infinity],
      [-91, 106],
      [91, 106],
      [10, -181],
      [10, 181],
    ]) {
      expect(BranchLocation.parse(pair[0], pair[1]), isNull);
    }
    expect(BranchLocation.parse(0, 0)!.coordinates, '0.0,0.0');
    expect(BranchLocation.parse(90, 180), isNotNull);
    expect(BranchLocation.parse(90, 180)!.supportsTiles, isFalse);
  });
  test('public discovery parser retains exact valid GPS and drops invalid pairs without losing branch', () async {
    final source = DiscoveryRemoteDataSource(
      Dio()
        ..httpClientAdapter = FakeAdapter(
          (_) => jsonResponse(200, {
            'content': [
              for (final gps in [
                {'latitude': 10.123456, 'longitude': 106.654321},
                {'latitude': 10.0, 'longitude': null},
                {'latitude': 100, 'longitude': 106},
                <String, dynamic>{},
              ])
                {
                  'id': 1,
                  'name': 'Sân A',
                  'address': 'A',
                  'city': 'HCM',
                  'courtCount': 2,
                  ...gps,
                },
            ],
            'page': 0,
            'totalPages': 1,
            'totalElements': 4,
          }),
        ),
    );
    final result = await source.search(query: '', page: 0);
    expect(result.branches.length, 4);
    expect(result.branches.first.location!.latitude, 10.123456);
    expect(result.branches.first.location!.longitude, 106.654321);
    expect(result.branches.skip(1).every((b) => b.location == null), isTrue);
  });
  test(
    'navigation URI uses documented Android scheme and no invented origin',
    () {
      final location = BranchLocation.parse(10.123456, 106.654321)!;
      expect(
        location.androidDirections.toString(),
        'google.navigation:q=10.123456,106.654321',
      );
      expect(
        location.googleDirections.queryParameters['destination'],
        location.coordinates,
      );
      expect(
        location.googleDirections.queryParameters.containsKey('origin'),
        isFalse,
      );
      expect(
        location.appleDirections.queryParameters['daddr'],
        location.coordinates,
      );
      expect(location.openStreetMap.host, 'www.openstreetmap.org');
    },
  );
  test(
    'native availability distinguishes key Play Services and unknown results',
    () async {
      for (final value in [
        'available',
        'missingKey',
        'unavailable',
        'future-status',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'availability');
              expect(call.arguments, isNull);
              return value;
            });
        final result = await DeviceBranchMapPlatform(
          platform: TargetPlatform.android,
        ).availability();
        expect(result, switch (value) {
          'available' => BranchMapAvailability.available,
          'missingKey' => BranchMapAvailability.missingKey,
          _ => BranchMapAvailability.unavailable,
        });
      }
    },
  );
  test(
    'missing native handler and non Android platforms safely use fallback',
    () async {
      expect(
        await DeviceBranchMapPlatform(platform: TargetPlatform.android)
            .availability(),
        BranchMapAvailability.unavailable,
      );
      expect(
        await DeviceBranchMapPlatform(platform: TargetPlatform.iOS)
            .availability(),
        BranchMapAvailability.unavailable,
      );
    },
  );
  test(
    'Android native navigation precedes HTTPS and handles launch exceptions',
    () async {
      final calls = <Uri>[];
      final maps = DeviceBranchMapPlatform(
        platform: TargetPlatform.android,
        opener: (url) async {
          calls.add(url);
          if (calls.length == 1)
            throw PlatformException(code: 'unavailable');
          return true;
        },
      );
      expect(await maps.directions(BranchLocation.parse(10, 106)!), isTrue);
      expect(calls.map((u) => u.scheme), ['google.navigation', 'https']);
      expect(calls.last.host, 'www.google.com');
    },
  );
  test(
    'successful native launch needs no browser request; iOS uses Apple Maps',
    () async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final calls = <Uri>[];
        final maps = DeviceBranchMapPlatform(
          platform: platform,
          opener: (uri) async {
            calls.add(uri);
            return true;
          },
        );
        expect(await maps.directions(BranchLocation.parse(10, 106)!), isTrue);
        expect(calls.length, 1);
        expect(
          calls.single.host,
          platform == TargetPlatform.iOS ? 'maps.apple.com' : '',
        );
      }
    },
  );
  test(
    'browser and attribution failures return actionable false without throwing',
    () async {
      final maps = DeviceBranchMapPlatform(
        platform: TargetPlatform.android,
        opener: (_) async => false,
      );
      final location = BranchLocation.parse(10, 106)!;
      expect(await maps.directions(location), isFalse);
      expect(await maps.openStreetMap(location), isFalse);
      expect(await maps.attribution(), isFalse);
    },
  );
}
