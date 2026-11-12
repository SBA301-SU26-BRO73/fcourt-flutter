import '../../../../../app/widgets/fc_widgets.dart';
import '../../../../../app/widgets/sport_icon.dart';

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
                              borderRadius: BorderRadius.circular(Radii.lg),
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
                            if (maps != null && data.location != null) ...[
                              BranchMapCard(
                                key: ValueKey(branchId),
                                location: data.location,
                                name: data.name,
                                platform: maps!,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (data.distanceKm != null) ...[
                              LabelIcon(
                                Icons.location_on_outlined,
                                '${data.distanceKm!.toStringAsFixed(1)} km',
                              ),
                              const SizedBox(height: Gap.xl),
                            ],
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
                            const SizedBox(height: Gap.xl),
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
                : () => context.push(
                    '/branches/$branchId/slots?branchName=${Uri.encodeQueryComponent(data.name)}',
                  ),
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
              child: FcCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.xs,
                ),
                onTap: () => context.push(
                  '/branches/${widget.branchId}/slots?court=${court.id}&branchName=${Uri.encodeQueryComponent(widget.branch.name)}',
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _SportBadge(_sportName(court.courtTypeId)),
                  title: Text(court.name),
                  subtitle: Text(_courtPrice(court)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
        ],
      );
    },
  );
}

String? _sportName(int courtTypeId) {
  for (final sport in DiscoverySport.values) {
    if (sport.typeId == courtTypeId) return sport.label;
  }
  return null;
}

class _SportBadge extends StatelessWidget {
  const _SportBadge(this.sport);
  final String? sport;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: SportIcon.named(sport, size: 22, color: colors.onPrimaryContainer),
    );
  }
}
