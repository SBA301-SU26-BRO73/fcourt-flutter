import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/branch_location.dart';

typedef MapUrlOpener = Future<bool> Function(Uri url);

class DeviceBranchMapPlatform implements BranchMapPlatform {
  DeviceBranchMapPlatform({
    MethodChannel? channel,
    MapUrlOpener? opener,
    TargetPlatform? platform,
  }) : _channel = channel ?? const MethodChannel('com.bro73.fcourt/maps'),
       _opener = opener ?? _open,
       _platform = platform ?? defaultTargetPlatform;
  final MethodChannel _channel;
  final MapUrlOpener _opener;
  final TargetPlatform _platform;
  static Future<bool> _open(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
  Future<bool> _try(Uri url) async {
    try {
      return await _opener(url);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BranchMapAvailability> availability() async {
    if (kIsWeb || _platform != TargetPlatform.android) {
      return BranchMapAvailability.unavailable;
    }
    try {
      return switch (await _channel
          .invokeMethod<String>('availability')
          .timeout(const Duration(seconds: 5))) {
        'available' => BranchMapAvailability.available,
        'missingKey' => BranchMapAvailability.missingKey,
        _ => BranchMapAvailability.unavailable,
      };
    } catch (_) {
      return BranchMapAvailability.unavailable;
    }
  }

  @override
  Future<bool> directions(BranchLocation location) async {
    if (!kIsWeb &&
        _platform == TargetPlatform.android &&
        await _try(location.androidDirections)) {
      return true;
    }
    if (!kIsWeb &&
        _platform == TargetPlatform.iOS &&
        await _try(location.appleDirections)) {
      return true;
    }
    return _try(location.googleDirections);
  }

  @override
  Future<bool> openStreetMap(BranchLocation location) =>
      _try(location.openStreetMap);
  @override
  Future<bool> attribution() =>
      _try(Uri.https('www.openstreetmap.org', '/copyright'));
}
