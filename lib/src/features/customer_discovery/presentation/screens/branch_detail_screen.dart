import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/error/failure.dart';

import '../../../../../features/maps/domain/branch_location.dart';
import '../../../../../features/maps/presentation/branch_map_card.dart';
import '../../../../../features/reviews/domain/review.dart';
import '../../../../../features/reviews/presentation/review_list_widget.dart';

import '../../../branch_gallery/domain/branch_image.dart';
import '../../../branch_gallery/presentation/branch_gallery_section.dart';
import '../../domain/discovery_repository.dart';
import '../widgets/discovery_widgets.dart';

class BranchDetailScreen extends StatelessWidget {
  const BranchDetailScreen({
    super.key,
    required this.branchId,
    this.branch,
    this.maps,
    this.galleryRepository,
    this.reviews,
    this.discoveryRepository,
  });
  final BranchMapPlatform? maps;
  final ReviewRepository? reviews;
  final int branchId;
  final Branch? branch;

  /// Nguồn ảnh chi nhánh (SCRUM-48); null thì giữ ảnh minh họa mặc định.
  final BranchImageRepository? galleryRepository;
  final DiscoveryRepository? discoveryRepository;

  @override
  Widget build(BuildContext context) {
    final data = branch;
    if (data == null || data.id != branchId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết chi nhánh')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DiscoveryMessage(
                message: 'Vui lòng mở chi nhánh từ danh sách tìm kiếm.',
              ),
              FilledButton(
                onPressed: () => context.go('/branches'),
                child: const Text('Tìm chi nhánh'),
              ),
            ],
          ),
        ),
      );
    }
    const artwork = CourtArtwork(height: 210, label: 'Ảnh sân chưa cập nhật');
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết chi nhánh')),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Thông tin'),
                Tab(text: 'Đánh giá'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: galleryRepository == null
                                  ? artwork
                                  : BranchGallerySection(
                                      repository: galleryRepository!,
                                      branchId: branchId,
                                      placeholder: artwork,
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
                              [data.address, data.district, data.city]
                                  .whereType<String>()
                                  .where((s) => s.isNotEmpty)
                                  .join(', '),
                            ),
                            const SizedBox(height: 16),
                            if (maps != null) ...[
                              BranchMapCard(
                                key: ValueKey(branchId),
                                location: data.location,
                                name: data.name,
                                platform: maps!,
                              ),
                              const SizedBox(height: 16),
                            ],
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
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
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
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
                                LabelIcon(
                                  Icons.local_parking,
                                  'Bãi xe · Chưa cập nhật',
                                ),
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
                            if (discoveryRepository != null)
                              _BranchCourts(
                                repository: discoveryRepository!,
                                branchId: branchId,
                                branch: data,
                              )
                            else
                              const Text('Chi nhánh chưa có sân hoạt động.'),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  reviews == null
                      ? const Center(child: Text('Đánh giá chưa khả dụng'))
                      : ReviewListWidget(
                          repository: reviews!,
                          branchId: branchId,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Đặt sân ngay'),
            onPressed: discoveryRepository == null
                ? null
                : () async {
                    late final List<Court> courts;
                    try {
                      courts = await discoveryRepository!.courtsOfBranch(
                        branchId,
                      );
                    } on Object {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Không tải được danh sách sân. Vui lòng thử lại.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (!context.mounted) return;
                    if (courts.length == 1) {
                      context.push(
                        '/courts/${courts.single.id}/slots?courtName=${Uri.encodeQueryComponent(courts.single.name)}&branchName=${Uri.encodeQueryComponent(data.name)}',
                      );
                    } else if (courts.length > 1) {
                      showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (sheetContext) => SafeArea(
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(16),
                            children: [
                              const ListTile(
                                title: Text('Chọn sân để xem lịch'),
                              ),
                              for (final court in courts)
                                ListTile(
                                  title: Text(court.name),
                                  subtitle: Text(
                                    '${NumberFormat.decimalPattern('vi').format(court.defaultPricePerHour)} đ/giờ',
                                  ),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    context.push(
                                      '/courts/${court.id}/slots?courtName=${Uri.encodeQueryComponent(court.name)}&branchName=${Uri.encodeQueryComponent(data.name)}',
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chi nhánh chưa có sân hoạt động.'),
                        ),
                      );
                    }
                  },
          ),
        ),
      ),
    );
  }
}

class _BranchCourts extends StatefulWidget {
  const _BranchCourts({
    required this.repository,
    required this.branchId,
    required this.branch,
  });
  final DiscoveryRepository repository;
  final int branchId;
  final Branch branch;

  @override
  State<_BranchCourts> createState() => _BranchCourtsState();
}

class _BranchCourtsState extends State<_BranchCourts> {
  late Future<List<Court>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.repository.courtsOfBranch(widget.branchId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Court>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        final message = snapshot.error is Failure
            ? (snapshot.error as Failure).message
            : 'Không tải được danh sách sân. Vui lòng thử lại.';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            TextButton.icon(
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        );
      }
      final courts = snapshot.data ?? const <Court>[];
      if (courts.isEmpty) return const Text('Chi nhánh chưa có sân hoạt động.');
      return Column(
        children: [
          for (final court in courts)
            Card(
              child: ListTile(
                leading: const Icon(Icons.sports_tennis),
                title: Text(court.name),
                subtitle: Text(
                  '${NumberFormat.decimalPattern('vi').format(court.defaultPricePerHour)} đ/giờ',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '/courts/${court.id}/slots?courtName=${Uri.encodeQueryComponent(court.name)}&branchName=${Uri.encodeQueryComponent(widget.branch.name)}',
                ),
              ),
            ),
        ],
      );
    },
  );
}
