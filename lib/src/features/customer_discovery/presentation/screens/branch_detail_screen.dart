import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/tokens.dart';
import '../../../../../app/widgets/wp3b_widgets.dart';
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

void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/discover');

AppBar _branchAppBar(BuildContext context) => AppBar(
  title: const Text('Chi tiết chi nhánh'),
  leading: BackButton(onPressed: () => _back(context)),
);

String _courtPrice(Court court) => court.defaultPricePerHour == null
    ? 'Giá theo khung giờ'
    : '${NumberFormat.decimalPattern('vi').format(court.defaultPricePerHour)}đ/giờ';

String? _sportName(int courtTypeId) {
  for (final sport in DiscoverySport.values) {
    if (sport.typeId == courtTypeId) return sport.label;
  }
  return null;
}

class _BranchDetailContent extends StatefulWidget {
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
  State<_BranchDetailContent> createState() => _BranchDetailContentState();
}

class _BranchDetailContentState extends State<_BranchDetailContent> {
  Future<List<Court>>? _courts;

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  @override
  void didUpdateWidget(_BranchDetailContent old) {
    super.didUpdateWidget(old);
    if (old.branchId != widget.branchId ||
        old.discoveryRepository != widget.discoveryRepository) {
      _loadCourts();
    }
  }

  void _loadCourts() {
    _courts = widget.discoveryRepository?.courtsOfBranch(widget.branchId);
  }

  void _openReviews() {
    final reviews = widget.reviews;
    if (reviews == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: ReviewListWidget(repository: reviews, branchId: widget.branchId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.branch;
    if (data == null || data.id != widget.branchId) {
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final price = data.minPrice == null
        ? 'Chưa cập nhật'
        : 'Từ ${NumberFormat.decimalPattern('vi').format(data.minPrice)}đ';
    final address = [
      data.address,
      data.district,
      data.city,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return Scaffold(
      appBar: _branchAppBar(context),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: FutureBuilder<List<Court>>(
              future: _courts,
              builder: (context, snapshot) {
                final courts = snapshot.data;
                final sport = courts == null || courts.isEmpty
                    ? null
                    : _sportName(courts.first.courtTypeId);
                final placeholder = SportPhoto(sport: sport);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    2,
                    20,
                    FloatingBottomBar.clearance,
                  ),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: SizedBox(
                        height: 304,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            widget.galleryRepository == null
                                ? placeholder
                                : BranchGallerySection(
                                    repository: widget.galleryRepository!,
                                    branchId: widget.branchId,
                                    placeholder: placeholder,
                                    height: 304,
                                  ),
                            Positioned(
                              left: 12,
                              right: 12,
                              top: 12,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  CircleIconButton(
                                    icon: Icons.chevron_left,
                                    tooltip: 'Quay lại',
                                    onImage: true,
                                    onPressed: () => _back(context),
                                  ),
                                  if (widget.maps != null &&
                                      data.location != null)
                                    CircleIconButton(
                                      icon: Icons.map_outlined,
                                      tooltip: 'Xem bản đồ',
                                      onImage: true,
                                      onPressed: () => _showMap(data),
                                    ),
                                ],
                              ),
                            ),
                            if (sport != null)
                              Positioned(
                                left: 14,
                                bottom: 14,
                                child: IgnorePointer(
                                  child: _SportChip(sport: sport),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      data.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 24,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.9,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (address.isNotEmpty)
                      _InfoLine(icon: Icons.place_outlined, text: address),
                    if (data.distanceKm != null)
                      _InfoLine(
                        icon: Icons.near_me_outlined,
                        text:
                            '${data.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                      ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 17,
                            color: context.fc.success.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: data.reviewCount > 0
                                    ? [
                                        TextSpan(
                                          text: data.averageRating
                                              .toStringAsFixed(1)
                                              .replaceAll('.', ','),
                                          style: TextStyle(
                                            color: context.fc.success.color,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              ' · ${data.reviewCount} đánh giá',
                                        ),
                                      ]
                                    : const [
                                        TextSpan(text: 'Chưa có đánh giá'),
                                      ],
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (widget.reviews != null)
                            InkWell(
                              onTap: _openReviews,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Xem đánh giá',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 39,
                      thickness: 1,
                      color: colors.outlineVariant,
                    ),
                    Text(
                      'Chọn sân',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.discoveryRepository == null)
                      const _CourtsNote('Chi nhánh chưa có sân hoạt động.')
                    else if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot.hasError)
                      _CourtsError(
                        error: snapshot.error!,
                        onRetry: () => setState(_loadCourts),
                      )
                    else if (courts == null || courts.isEmpty)
                      const _CourtsNote('Chi nhánh chưa có sân hoạt động.')
                    else
                      for (final court in courts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: _CourtRow(
                            court: court,
                            onTap: () => context.push(
                              '/branches/${widget.branchId}/slots?court=${court.id}&branchName=${Uri.encodeQueryComponent(data.name)}',
                            ),
                          ),
                        ),
                    const SizedBox(height: 12),
                    Text(
                      'Giá tham khảo; giá chính xác được xác nhận khi chọn lịch.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: FloatingBottomBar(
        caption: 'Giá sân',
        priceText: price,
        priceUnit: data.minPrice == null ? null : '/giờ',
        actionLabel: 'Đặt sân',
        onAction: widget.discoveryRepository == null
            ? null
            : () => context.push(
                '/branches/${widget.branchId}/slots?branchName=${Uri.encodeQueryComponent(data.name)}',
              ),
      ),
    );
  }

  void _showMap(Branch data) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: BranchMapCard(
        key: ValueKey(widget.branchId),
        location: data.location,
        name: data.name,
        platform: widget.maps!,
      ),
    ),
  );
}

class _SportChip extends StatelessWidget {
  const _SportChip({required this.sport});
  final String sport;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SportIcon.named(sport, size: 13, color: const Color(0xFF354064)),
        const SizedBox(width: 4),
        Text(
          sport,
          style: const TextStyle(
            color: Color(0xFF354064),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtsNote extends StatelessWidget {
  const _CourtsNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _CourtsError extends StatelessWidget {
  const _CourtsError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _CourtsNote(
        error is Failure
            ? (error as Failure).message
            : 'Không tải được danh sách sân. Vui lòng thử lại.',
      ),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Thử lại'),
      ),
    ],
  );
}

/// Mock-up "slot" row: 16dp corners, 1dp line, 12/14 padding.
class _CourtRow extends StatelessWidget {
  const _CourtRow({required this.court, required this.onTap});
  final Court court;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryContainer,
                ),
                child: Center(
                  child: SportIcon.named(
                    _sportName(court.courtTypeId),
                    size: 20,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _courtPrice(court),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
