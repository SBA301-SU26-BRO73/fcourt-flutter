import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import 'offline_coordinator.dart';
import 'offline_remote.dart';
import 'offline_store.dart';

bool get supportsOffline =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool offlineWorkerReady = false;
Future<void> queueOfflineWorker() async {
  if (!offlineWorkerReady) return;
  if (supportsOffline) {
    await Workmanager().registerOneOffTask(
      'fcourt-offline-drain',
      'fcourt-offline-drain',
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 10),
    );
  }
}

class OfflineRuntime {
  OfflineRuntime(AppConfig config, TokenStorage tokens) {
    coordinator = OfflineCoordinator(
      store: store,
      remote: HttpOfflineRemote(
        createDio(config, tokens, baseUrl: config.staffBaseUrl),
      ),
      identity: SecureOfflineIdentity(tokens),
      onQueued: queueOfflineWorker,
    );
  }
  Future<OfflineStore>? _store;
  late final OfflineCoordinator coordinator;
  StreamSubscription<List<ConnectivityResult>>? _network;
  Future<OfflineStore> store() => _store ??= OfflineStore.open();
  void start() {
    _network ??= Connectivity().onConnectivityChanged.listen((values) {
      if (values.any((v) => v != ConnectivityResult.none)) {
        unawaited(coordinator.flush());
      }
    });
    unawaited(coordinator.shiftSync());
  }

  Future<void> close() async {
    await _network?.cancel();
    coordinator.dispose();
    if (_store != null) await (await _store!).close();
  }
}

@pragma('vm:entry-point')
void offlineWorkerDispatcher() {
  Workmanager().executeTask((task, data) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task != 'fcourt-offline-drain') return true;
    final runtime = OfflineRuntime(
      AppConfig.fromEnvironment(),
      SecureTokenStorage(),
    );
    try {
      await runtime.coordinator.flush();
      return runtime.coordinator.pendingCount == 0 ||
          runtime.coordinator.authRequired;
    } catch (_) {
      return false;
    } finally {
      await runtime.close();
    }
  });
}

Future<void> initializeOfflineWorker() async {
  if (supportsOffline) {
    try {
      await Workmanager().initialize(offlineWorkerDispatcher);
      await Workmanager().registerPeriodicTask(
        'fcourt-offline-periodic',
        'fcourt-offline-drain',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      offlineWorkerReady = true;
    } catch (_) {
      offlineWorkerReady = false;
    }
  }
}
