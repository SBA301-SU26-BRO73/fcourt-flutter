import 'package:flutter/material.dart';

import '../../domain/discovery_repository.dart';
import '../widgets/discovery_widgets.dart';

class BranchDetailScreen extends StatelessWidget {
  const BranchDetailScreen({super.key, required this.branchId, this.branch});
  final int branchId;
  final Branch? branch;

  @override
  Widget build(BuildContext context) {
    final data = branch;
    if (data == null || data.id != branchId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết chi nhánh')),
        body: const Center(
          child: DiscoveryMessage(
            message: 'Vui lòng mở chi nhánh từ danh sách tìm kiếm.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết chi nhánh')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const CourtArtwork(
                    height: 210,
                    label: 'Ảnh sân chưa cập nhật',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  data.name,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    data.address,
                    data.district,
                    data.city,
                  ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    const LabelIcon(Icons.star_border, 'Chưa có đánh giá'),
                    LabelIcon(
                      Icons.location_on_outlined,
                      data.distanceKm == null
                          ? 'Khoảng cách chưa cập nhật'
                          : '${data.distanceKm!.toStringAsFixed(1)} km',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  branchPrice(data),
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const Text(
                  'Giá tham khảo; giá chính xác được xác nhận khi chọn lịch.',
                ),
                const SizedBox(height: 24),
                Text(
                  'Tiện ích sân',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    LabelIcon(Icons.wifi, 'Wifi · Chưa cập nhật'),
                    LabelIcon(Icons.local_parking, 'Bãi xe · Chưa cập nhật'),
                    LabelIcon(
                      Icons.local_cafe_outlined,
                      'Quầy nước · Chưa cập nhật',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Sân trong chi nhánh (${data.courtCount})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  data.courtCount == 0 ? 'Chi nhánh chưa có sân hoạt động.' : 'Danh sách sân đang được cập nhật. Vui lòng quay lại sau.',
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Đặt sân ngay'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (context) => const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Chưa thể chọn lịch vì danh sách sân chưa được cập nhật. '
                    'Vui lòng thử lại sau.',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
