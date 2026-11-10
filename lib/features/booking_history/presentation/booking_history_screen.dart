import '../../../app/widgets/account_actions.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../domain/booking.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({
    super.key,
    required this.repository,
    required this.onDetail,
    this.onTransactions,
    this.onReview,
  });
  final BookingRepository repository;
  final FutureOr<void> Function(int) onDetail;
  final VoidCallback? onTransactions;
  final Future<void> Function(int)? onReview;
  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen>
    with WidgetsBindingObserver {
  static const filters = ['ALL', 'UPCOMING', 'COMPLETED', 'CANCELLED'];
  int _tab = 0, _page = 0, _generation = 0;
  List<Booking> _items = [];
  bool _loading = false, _more = false;
  String? _error;
  Timer? _ticker;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(reset: true);
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _generation++;
    _ticker?.cancel();
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
        _items = [];
        _more = false;
      }
    });
    try {
      final result = await widget.repository.history(filters[_tab], page: page);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = reset
            ? result.items
            : [
                ..._items,
                ...result.items.where((b) => !_items.any((i) => i.id == b.id)),
              ];
        _page = page;
        _more = result.hasMore;
      });
    } on Failure catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = [..._items]
      ..sort((a, b) {
        final date = b.date.compareTo(a.date);
        return date != 0 ? date : b.id.compareTo(a.id);
      });
    final days = <String, List<Booking>>{};
    for (final booking in items) {
      days.putIfAbsent(booking.date, () => []).add(booking);
    }
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateFormat('yyyy-MM-dd').format(now);
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5540BB), Color(0xFF6B58D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Đã đặt',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const AccountActions(color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Lịch sân của bạn, sẵn sàng cho buổi chơi tiếp theo.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        Icon(
                          Icons.confirmation_number_outlined,
                          color: Colors.white70,
                          size: 54,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < filters.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          [
                            'Tất cả',
                            'Sắp diễn ra',
                            'Đã hoàn thành',
                            'Đã hủy',
                          ][i],
                        ),
                        selected: _tab == i,
                        onSelected: (_) {
                          if (_tab != i) {
                            setState(() => _tab = i);
                            _load(reset: true);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Đơn đặt sân của bạn',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (widget.onTransactions != null)
                        IconButton(
                          tooltip: 'Lịch sử thanh toán',
                          onPressed: widget.onTransactions,
                          icon: const Icon(Icons.receipt_long_outlined),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    Text(_error!),
                    TextButton(
                      onPressed: () => _load(reset: _items.isEmpty),
                      child: const Text('Thử lại'),
                    ),
                  ],
                  if (!_loading && _items.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_note_outlined,
                            size: 72,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 18),
                          Text(
                            'Chưa có đơn đặt sân',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  for (final day in days.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 12),
                      child: Text(
                        '${day.key == today ? 'Hôm nay · ' : ''}${DateFormat('dd/MM/yyyy').format(DateTime.parse(day.key))}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final booking in day.value)
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await widget.onDetail(booking.id);
                          if (mounted) await _load(reset: true);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colors.primaryContainer,
                                    foregroundColor: colors.primary,
                                    child: const Icon(Icons.sports_tennis),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${booking.branchName} · ${booking.courtName}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          booking.slots.join(' · '),
                                          style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Mã đơn: ${booking.code}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: booking.status == 'CANCELLED'
                                          ? colors.errorContainer
                                          : colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      booking.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: booking.status == 'CANCELLED'
                                            ? colors.onErrorContainer
                                            : colors.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    NumberFormat.currency(
                                      locale: 'vi_VN',
                                      symbol: 'đ',
                                      decimalDigits: 0,
                                    ).format(booking.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if ({
                                    'CONFIRMED',
                                    'PENDING_PAYMENT',
                                    'AWAITING_CONFIRMATION',
                                  }.contains(booking.status))
                                    Text(
                                      booking.countdown(DateTime.now()),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  if (booking.status == 'COMPLETED' &&
                                      widget.onReview != null)
                                    TextButton(
                                      onPressed: () =>
                                          widget.onReview!(booking.id),
                                      child: const Text('Đánh giá sân'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_more && !_loading)
                    TextButton(
                      onPressed: () => _load(),
                      child: const Text('Xem thêm'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
