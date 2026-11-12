import '../../../app/widgets/fc_widgets.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import 'booking_style.dart';
import '../../../app/widgets/skeleton_list.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/error/failure.dart';
import '../domain/booking.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({
    super.key,
    required this.repository,
    required this.onDetail,
    this.onTransactions,
    this.onReview,
    this.cacheUserId,
    FlutterSecureStorage? cacheStorage,
  }) : _cacheStorage = cacheStorage ?? const FlutterSecureStorage();
  final BookingRepository repository;
  final FutureOr<void> Function(int) onDetail;
  final VoidCallback? onTransactions;
  final Future<bool> Function(int)? onReview;
  final int? cacheUserId;
  final FlutterSecureStorage _cacheStorage;
  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen>
    with WidgetsBindingObserver {
  static const filters = ['ALL', 'UPCOMING', 'COMPLETED', 'CANCELLED'];
  int _tab = 0, _page = 0, _generation = 0;
  int _networkLoadedTab = -1;
  List<Booking> _items = [];
  bool _loading = false, _more = false;
  bool _offline = false;
  String? _error;
  Timer? _ticker;
  final _search = TextEditingController();
  final Set<int> _reviewed = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreCache());
    _load(reset: true);
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _generation++;
    _ticker?.cancel();
    _search.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final generation = ++_generation, page = reset ? 0 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _more = false;
      }
    });
    try {
      final result = await widget.repository.history(filters[_tab], page: page);
      if (!mounted || generation != _generation) return;
      _networkLoadedTab = _tab;
      setState(() {
        _offline = false;
        _items = reset
            ? result.items
            : [
                ..._items,
                ...result.items.where((b) => !_items.any((i) => i.id == b.id)),
              ];
        _page = page;
        _more = result.hasMore;
      });
      unawaited(_saveCache(_items));
    } on Failure catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _offline = e is NetworkFailure && _items.isNotEmpty;
          _error = _offline ? null : e.message;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  String? get _cacheKey => widget.cacheUserId == null
      ? null
      : 'fcourt.booking.history.v1.${widget.cacheUserId}.${filters[_tab]}';

  Future<void> _saveCache(List<Booking> bookings) async {
    final key = _cacheKey;
    if (key == null) return;
    try {
      await widget._cacheStorage.write(
        key: key,
        value: jsonEncode([
          for (final booking in bookings)
            {
              'id': booking.id,
              'code': booking.code,
              'branchName': booking.branchName,
              'courtName': booking.courtName,
              'date': booking.date,
              'slots': booking.slots,
              'amount': booking.amount,
              'status': booking.status,
              'address': booking.address,
            },
        ]),
      );
    } catch (_) {
      // A local cache failure must not affect the live booking list.
    }
  }

  Future<void> _restoreCache() async {
    final tab = _tab;
    final key = _cacheKey;
    if (key == null) return;
    try {
      final raw = await widget._cacheStorage.read(key: key);
      if (!mounted || raw == null || _items.isNotEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final cached = <Booking>[];
      for (final row in decoded) {
        if (row is! Map<String, dynamic> ||
            row['id'] is! int ||
            row['code'] is! String ||
            row['branchName'] is! String ||
            row['courtName'] is! String ||
            row['date'] is! String ||
            row['slots'] is! List ||
            row['amount'] is! int ||
            row['status'] is! String) {
          return;
        }
        cached.add(
          Booking(
            id: row['id'] as int,
            code: row['code'] as String,
            branchName: row['branchName'] as String,
            courtName: row['courtName'] as String,
            date: row['date'] as String,
            slots: (row['slots'] as List).whereType<String>().toList(),
            amount: row['amount'] as int,
            status: row['status'] as String,
            address: row['address'] as String?,
          ),
        );
      }
      if (cached.isNotEmpty &&
          mounted &&
          tab == _tab &&
          _networkLoadedTab != tab &&
          _items.isEmpty) {
        setState(() {
          _items = cached;
          _offline = true;
          _error = null;
        });
      }
    } catch (_) {
      // Ignore malformed or unavailable cache and use the network result.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final query = _search.text.trim().toLowerCase();
    final items =
        [
          for (final b in _items)
            if (query.isEmpty ||
                b.code.toLowerCase().contains(query) ||
                b.branchName.toLowerCase().contains(query))
              b,
        ]..sort((a, b) {
          final date = b.date.compareTo(a.date);
          return date != 0 ? date : b.id.compareTo(a.id);
        });
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              FloatingNavBar.clearance,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 58,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đơn của tôi',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 25,
                          letterSpacing: -.9,
                        ),
                      ),
                    ),
                    if (widget.onTransactions != null)
                      CircleIconButton(
                        icon: Icons.receipt_long_outlined,
                        tooltip: 'Lịch sử thanh toán',
                        onPressed: widget.onTransactions,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              _SearchPill(
                controller: _search,
                hint: 'Tìm mã đơn hoặc tên sân',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 35,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (int i = 0; i < filters.length; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      _FilterPill(
                        label: _filterLabels[i],
                        selected: _tab == i,
                        onTap: () {
                          if (_tab == i) return;
                          setState(() {
                            _tab = i;
                            _networkLoadedTab = -1;
                            _items = [];
                            _offline = false;
                            _error = null;
                          });
                          _load(reset: true);
                          _restoreCache();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (_offline)
                Container(
                  key: const ValueKey('bookings-offline-banner'),
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Ngoại tuyến · đang hiển thị danh sách đã tải gần đây',
                  ),
                ),
              if (_error != null) ...[
                Text(_error!),
                TextButton(
                  onPressed: () => _load(reset: _items.isEmpty),
                  child: const Text('Thử lại'),
                ),
              ],
              if (!_loading && _items.isNotEmpty && items.isEmpty)
                const EmptyState(
                  icon: Icons.search_off_outlined,
                  message: 'Không có đơn khớp từ khóa đã nhập',
                ),
              if (!_loading && _items.isEmpty && _error == null)
                const EmptyState(
                  icon: Icons.event_note_outlined,
                  message: 'Chưa có đơn đặt sân',
                ),
              for (final booking in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: _OrderCard(
                    booking: booking,
                    reviewed: _reviewed.contains(booking.id),
                    onOpen: () async {
                      await widget.onDetail(booking.id);
                      if (mounted) await _load(reset: true);
                    },
                    onReview: widget.onReview == null
                        ? null
                        : () async {
                            if (await widget.onReview!(booking.id) && mounted) {
                              setState(() => _reviewed.add(booking.id));
                            }
                          },
                  ),
                ),
              if (_loading)
                _items.isEmpty
                    ? const SkeletonList()
                    : const Center(child: CircularProgressIndicator()),
              if (_more && !_loading)
                TextButton(
                  onPressed: () => _load(),
                  child: const Text('Xem thêm'),
                )
              else if (!_loading && items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: Text(
                      'Bạn đã xem hết đơn đặt sân',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const _filterLabels = ['Tất cả', 'Sắp diễn ra', 'Đã hoàn thành', 'Đã hủy'];

/// Mock-up ".search": 48dp pill with a 1dp line, icon 18 and 12dp hint.
class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Xóa tìm kiếm',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                controller.clear();
                onChanged();
              },
            ),
        ],
      ),
    );
  }
}

/// Mock-up ".filters .pill": 11/600, 10/13 padding; selected = solid accent.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primary : colors.surfaceContainer,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: selected ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mock-up ".order": code and status tag, photo with name and lines, total
/// and one clear action.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.booking,
    required this.reviewed,
    required this.onOpen,
    this.onReview,
  });
  final Booking booking;
  final bool reviewed;
  final VoidCallback onOpen;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tone = booking.tone(context);
    final upcoming = const {
      'CONFIRMED',
      'PENDING_PAYMENT',
      'AWAITING_CONFIRMATION',
    }.contains(booking.status);
    final needsReceipt = booking.status == 'PENDING_PAYMENT';
    final canReview =
        booking.status == 'COMPLETED' && onReview != null && !reviewed;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 10,
    );
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(23),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${booking.code}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TintTag(booking.tagLabel, tone: tone),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      width: 74,
                      height: 82,
                      child: SportPhoto(kind: booking.sportKind),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.branchName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(booking.dateAndSlots, style: muted),
                        const SizedBox(height: 5),
                        Text(booking.sportAndCourt, style: muted),
                        if (upcoming) ...[
                          const SizedBox(height: 5),
                          Text(
                            booking.countdown(DateTime.now()),
                            style: muted?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Divider(height: 31, thickness: 1, color: colors.outlineVariant),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tổng thanh toán',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    booking.amountText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              if (needsReceipt || canReview) ...[
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: needsReceipt
                      ? FilledButton(
                          onPressed: onOpen,
                          style: _smallAction(context),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Gửi biên lai'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 15),
                            ],
                          ),
                        )
                      : OutlinedButton(
                          onPressed: onReview,
                          style: _smallAction(context),
                          child: const Text('Đánh giá sân'),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mock-up ".order .primary": 12/700 label, 12dp vertical padding.
ButtonStyle _smallAction(BuildContext context) => FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(44),
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  textStyle: Theme.of(context).textTheme.labelLarge
      ?.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
);
