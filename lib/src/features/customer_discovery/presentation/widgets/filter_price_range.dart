import 'package:flutter/material.dart';

import '../../domain/discovery_filters.dart';

class FilterPriceRange extends StatefulWidget {
  const FilterPriceRange({
    super.key,
    required this.minPrice,
    required this.maxPrice,
    required this.onChanged,
  });
  final String minPrice, maxPrice;
  final void Function(String min, String max) onChanged;

  @override
  State<FilterPriceRange> createState() => _FilterPriceRangeState();
}

class _FilterPriceRangeState extends State<FilterPriceRange> {
  late final _min = TextEditingController(text: widget.minPrice);
  late final _max = TextEditingController(text: widget.maxPrice);
  RangeValues? _bounds;

  @override
  void initState() {
    super.initState();
    _setBounds();
  }

  void _setBounds() {
    final min = double.tryParse(_min.text.trim());
    final max = double.tryParse(_max.text.trim());
    _bounds = min != null && max != null && min < max && _errors.isEmpty
        ? RangeValues(min, max)
        : null;
  }

  Map<String, String> get _errors =>
      DiscoveryFilters(minPrice: _min.text, maxPrice: _max.text).errors;

  void _typed(String _) {
    setState(_setBounds);
    widget.onChanged(_min.text, _max.text);
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds;
    final errors = _errors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Khoảng giá (đ/slot)'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _min,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: _typed,
                decoration: InputDecoration(
                  labelText: 'Giá từ',
                  errorText: errors['minPrice'],
                  errorMaxLines: 3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _max,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: _typed,
                decoration: InputDecoration(
                  labelText: 'Giá đến',
                  errorText: errors['maxPrice'],
                  errorMaxLines: 3,
                ),
              ),
            ),
          ],
        ),
        if (bounds == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nhập hai mốc giá để điều chỉnh bằng thanh kéo.'),
          )
        else
          RangeSlider(
            min: bounds.start,
            max: bounds.end,
            values: RangeValues(
              double.parse(_min.text),
              double.parse(_max.text),
            ),
            labels: RangeLabels('${_min.text} đ', '${_max.text} đ'),
            onChanged: (values) {
              setState(() {
                _min.text = values.start.toStringAsFixed(2);
                _max.text = values.end.toStringAsFixed(2);
              });
              widget.onChanged(_min.text, _max.text);
            },
          ),
      ],
    );
  }
}
