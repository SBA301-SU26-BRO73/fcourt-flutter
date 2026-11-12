import 'package:flutter/material.dart';

import '../../../app/widgets/fc_widgets.dart';
import '../data/offline_runtime.dart';

/// Trạng thái đồng bộ gọn một dòng: chip trạng thái và nút "Đồng bộ".
/// Chi tiết (lượt cần đối soát, lưu ý khi mất mạng) chỉ mở khi cần.
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
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: ExpansionTile(
          key: const ValueKey('offline-summary'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              synced
                  ? 'Đã đồng bộ'
                  : 'Chờ gửi ${state.pendingCount} · Cần đối soát ${state.conflictCount}',
              tone: synced ? context.fc.success : context.fc.warning,
              icon: synced ? Icons.cloud_done_outlined : Icons.sync_problem,
            ),
          ),
          children: [
            Text(state.message, style: theme.textTheme.bodySmall),
            if (!offlineWorkerReady)
              Text(
                'Chưa có worker nền. Mở ứng dụng khi có mạng để đồng bộ lượt đang chờ.',
                style: theme.textTheme.bodySmall,
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
                  label: const Text('Tải vé đầu ca'),
                ),
                TextButton.icon(
                  onPressed: state.flush,
                  icon: const Icon(Icons.sync),
                  label: const Text('Đồng bộ ngay'),
                ),
              ],
            ),
            Text(
              'Khi mất mạng, vé chỉ được xác nhận trên máy này và cần đối soát khi có mạng.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    },
  );
}
