import '../../../../../app/widgets/fc_widgets.dart';

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

class BranchDetailScreen extends StatefulWidget {
  const BranchDetailScreen({
    super.key,
    required this.branchId,
    this.branch,
    this.maps,
    this.galleryRepository,
    this.reviews,
    this.discoveryRepository,
  });
  final int branchId;
  final Branch? branch;
  final BranchMapPlatform? maps;
  final BranchImageRepository? galleryRepository;
  final ReviewRepository? reviews;
  final DiscoveryRepository? discoveryRepository;
  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  Branch? _branch;
  bool _loading = false;
  String? _error;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BranchDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId ||
        oldWidget.branch != widget.branch) {
      _load();
    }
  }

  Future<void> _load() async {
    final revision = ++_revision;
    _branch = widget.branch?.id == widget.branchId ? widget.branch : null;
    _error = null;
    final repository = widget.discoveryRepository;
    if (_branch != null || repository is! BranchDetailRepository) {
      _loading = false;
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await (repository as BranchDetailRepository).branchById(
        widget.branchId,
      );
      if (mounted && revision == _revision) setState(() => _branch = result);
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(
          () => _error = error is Failure
              ? error.message
              : 'Không tải được chi nhánh. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return Scaffold(
        appBar: _branchAppBar(context),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : DiscoveryMessage(message: _error!, onRetry: _load),
        ),
      );
    }
    return _BranchDetailContent(
      branchId: widget.branchId,
      branch: _branch,
      maps: widget.maps,
      galleryRepository: widget.galleryRepository,
      reviews: widget.reviews,
      discoveryRepository: widget.discoveryRepository,
    );
  }
}

AppBar _branchAppBar(BuildContext context) => AppBar(
  title: const Text('Chi tiết chi nhánh'),
  leading: BackButton(
    onPressed: () => context.canPop() ? context.pop() : context.go('/discover'),
  ),
);

String _courtPrice(Court court) => court.defaultPricePerHour == null
    ? 'Giá theo khung giờ · Chọn sân để xem lịch'
    : '${NumberFormat.decimalPattern('vi').format(court.defaultPricePerHour)} đ/giờ';

class _BranchDetailContent extends StatelessWidget {
  const _BranchDetailContent({
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
        appBar: _branchAppBar(context),
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
      appBar: _branchAppBar(context),
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
                              borderRadius: BorderRadius.circular(Radii.xl),
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
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              [data.address, data.district, data.city]
                                  .whereType<String>()
                                  .where((s) => s.isNotEmpty)
                                  .join(', '),
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Chọn sân trong chi nhánh',
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
                      showDialog<void>(
                        context: context,
                        useRootNavigator: true,
                        builder: (sheetContext) => Dialog(
                          insetPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 48,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 440,
                              maxHeight: 560,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    20,
                                    8,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Chọn sân để xem lịch',
                                          style: Theme.of(sheetContext)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Đóng',
                                        icon: const Icon(Icons.close),
                                        onPressed: () =>
                                            Navigator.pop(sheetContext),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Flexible(
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    itemCount: courts.length,
                                    separatorBuilder: (_, _) => const Divider(
                                      height: 1,
                                      indent: 24,
                                      endIndent: 24,
                                    ),
                                    itemBuilder: (_, index) {
                                      final court = courts[index];
                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                        leading: const Icon(
                                          Icons.stadium_outlined,
                                        ),
                                        title: Text(court.name),
                                        subtitle: Text(_courtPrice(court)),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                        onTap: () {
                                          Navigator.pop(sheetContext);
                                          context.push(
                                            '/courts/${court.id}/slots?courtName=${Uri.encodeQueryComponent(court.name)}&branchName=${Uri.encodeQueryComponent(data.name)}',
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: const IconBadge(Icons.sports_tennis, size: 42),
                  title: Text(court.name),
                  subtitle: Text(_courtPrice(court)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(
                    '/courts/${court.id}/slots?courtName=${Uri.encodeQueryComponent(court.name)}&branchName=${Uri.encodeQueryComponent(widget.branch.name)}',
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
