import 'dart:async';

import 'package:flutter/material.dart';

import '../data/offline_runtime.dart';

class OfflinePanel extends StatefulWidget {
  const OfflinePanel({super.key, required this.runtime});
  final OfflineRuntime runtime;
  @override
  State<OfflinePanel> createState() => _OfflinePanelState();
}

class _OfflinePanelState extends State<OfflinePanel>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.runtime.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.runtime.coordinator.flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.runtime.coordinator,
    builder: (context, _) {
      final state = widget.runtime.coordinator;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.message),
            if (!offlineWorkerReady)
              const Text(
                'Chưa có worker nền. Mở ứng dụng khi có mạng để đồng bộ lượt đang chờ.',
              ),
            Text(
              'Đang chờ: ${state.pendingCount} · Cần đối soát: ${state.conflictCount}',
            ),
            if (state.issues.isNotEmpty)
              ExpansionTile(
                title: const Text('Lượt cần đối soát'),
                children: state.issues
                    .map(
                      (issue) => ListTile(
                        title: Text('Booking #${issue['booking_id']}'),
                        subtitle: Text(
                          '${issue['occurred_at']} · Liên hệ quản lý, không quét lại để ghi đè.',
                        ),
                      ),
                    )
                    .toList(),
              ),
            Wrap(
              children: [
                TextButton.icon(
                  onPressed: state.busy ? null : state.shiftSync,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Đồng bộ đầu ca'),
                ),
                TextButton(
                  onPressed: state.flush,
                  child: const Text('Đẩy lượt đang chờ'),
                ),
              ],
            ),
            const Text(
              'Khi mất mạng, vé chỉ được xác nhận cục bộ trên máy này và cần đối soát khi có mạng.',
            ),
          ],
        ),
      );
    },
  );
}
