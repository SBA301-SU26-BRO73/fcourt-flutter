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
  });
  final BookingRepository repository;
  final FutureOr<void> Function(int) onDetail;
  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen>
    with WidgetsBindingObserver {
  static const filters = ['UPCOMING', 'COMPLETED', 'CANCELLED'];
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử đặt sân')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(['Sắp diễn ra', 'Đã hoàn thành', 'Đã hủy'][i]),
                  selected: _tab == i,
                  onSelected: (_) {
                    if (_tab != i) {
                      setState(() => _tab = i);
                      _load(reset: true);
                    }
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: () => _load(reset: _items.isEmpty),
                    child: const Text('Thử lại'),
                  ),
                ],
                if (!_loading && _items.isEmpty && _error == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Chưa có đơn đặt sân',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final booking in _items)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${booking.branchName} · ${booking.courtName}',
                      ),
                      subtitle: Text(
                        '${booking.date} · ${booking.slots.join(', ')}\n${booking.label}\n${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(booking.amount)}${_tab == 0 ? '\n${booking.countdown(DateTime.now())}' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await widget.onDetail(booking.id);
                        if (mounted) await _load(reset: true);
                      },
                    ),
                  ),
                if (_loading) const Center(child: CircularProgressIndicator()),
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
