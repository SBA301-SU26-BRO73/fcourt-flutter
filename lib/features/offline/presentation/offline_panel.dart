import 'package:flutter/material.dart';

import '../data/offline_runtime.dart';

class OfflinePanel extends StatefulWidget {
  const OfflinePanel({super.key, required this.runtime});
  final OfflineRuntime runtime;
  @override
  State<OfflinePanel> createState() => _OfflinePanelState();
}

class _OfflinePanelState extends State<OfflinePanel> {
  @override
  void initState() {
    super.initState();
    widget.runtime.start();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.runtime.coordinator,
    builder: (context, _) {
      final state = widget.runtime.coordinator;
      final synced = state.pendingCount == 0 && state.conflictCount == 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ExpansionTile(
          key: const ValueKey('offline-summary'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(
                synced ? Icons.cloud_done_outlined : Icons.sync_problem,
                size: 18,
              ),
              label: Text(
                synced
                    ? 'Đã đồng bộ'
                    : 'Chờ ${state.pendingCount} · Đối soát ${state.conflictCount}',
              ),
            ),
          ),
          children: [
            Text(state.message),
            if (!offlineWorkerReady)
              const Text(
                'Chưa có worker nền. Mở ứng dụng khi có mạng để đồng bộ lượt đang chờ.',
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
