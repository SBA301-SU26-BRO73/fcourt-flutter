import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/discovery_repository.dart';
import '../discovery_cubit.dart';
import 'discovery_widgets.dart';
import 'filter_price_range.dart';

class DiscoveryFilterSheet extends StatefulWidget {
  const DiscoveryFilterSheet({super.key});

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  late final _cubit = context.read<DiscoveryCubit>();
  late final _city = TextEditingController(text: _cubit.state.filters.city);
  late final _district = TextEditingController(
    text: _cubit.state.filters.district,
  );
  late final _time = TextEditingController(text: _cubit.state.filters.timeSlot);
  late bool _today = _cubit.state.filters.hasAvailableSlotsToday;
  late String _min = _cubit.state.filters.minPrice;
  late String _max = _cubit.state.filters.maxPrice;
  int _reset = 0;

  DiscoveryFilters get _draft => DiscoveryFilters(
    city: _city.text,
    district: _district.text,
    minPrice: _min,
    maxPrice: _max,
    timeSlot: _time.text,
    hasAvailableSlotsToday: _today,
  );

  void _changed() {
    setState(() {});
    _cubit.updateFilters(_draft);
  }

  void _resetFilters() {
    setState(() {
      _city.clear();
      _district.clear();
      _time.clear();
      _min = '';
      _max = '';
      _today = false;
      _reset++;
    });
    _cubit.resetFilters();
  }

  @override
  void dispose() {
    _city.dispose();
    _district.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: BlocBuilder<DiscoveryCubit, DiscoveryState>(
          builder: (context, state) {
            final errors = _draft.errors;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Bộ lọc nâng cao')),
                      TextButton(
                        onPressed: _resetFilters,
                        child: const Text('Đặt lại'),
                      ),
                      IconButton(
                        tooltip: 'Đóng bộ lọc',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      FilterChip(
                        label: const Text('Còn giờ trống hôm nay'),
                        selected: _today,
                        onSelected: (value) {
                          _today = value;
                          _changed();
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Loại sân'),
                      SportFilters(
                        selected: state.sport,
                        onSelected: _cubit.filter,
                      ),
                      const SizedBox(height: 16),
                      FilterPriceRange(
                        key: ValueKey(_reset),
                        minPrice: _min,
                        maxPrice: _max,
                        onChanged: (min, max) {
                          _min = min;
                          _max = max;
                          _changed();
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _city,
                        onChanged: (_) => _changed(),
                        decoration: InputDecoration(
                          labelText: 'Tỉnh / Thành phố',
                          errorText: errors['city'],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _district,
                        onChanged: (_) => _changed(),
                        decoration: InputDecoration(
                          labelText: 'Quận / Huyện',
                          errorText: errors['district'],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _time,
                        onChanged: (_) => _changed(),
                        decoration: InputDecoration(
                          labelText: 'Khung giờ hôm nay',
                          hintText: '18:00 - 20:00',
                          helperText: 'Bỏ trống để tìm mọi khung giờ. Không hỗ trợ qua đêm.',
                          helperMaxLines: 2,
                          errorText: errors['timeSlot'],
                          errorMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (errors.isNotEmpty)
                        const Text(
                          'Vui lòng kiểm tra bộ lọc để cập nhật kết quả',
                        )
                      else if (state.error != null) ...[
                        Text(state.error!),
                        TextButton(
                          onPressed: _cubit.refresh,
                          child: const Text('Thử lại'),
                        ),
                      ] else if (state.loading)
                        const LinearProgressIndicator()
                      else
                        Text(
                          '${state.total} chi nhánh phù hợp',
                          semanticsLabel: '${state.total} chi nhánh phù hợp',
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: errors.isEmpty
                            ? () => Navigator.pop(context)
                            : null,
                        child: const Text('Xem kết quả'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
