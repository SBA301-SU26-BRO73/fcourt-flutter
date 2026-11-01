import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/discovery_widgets.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() => context.push(
    Uri(
      path: '/branches',
      queryParameters: {'query': _query.text.trim()},
    ).toString(),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('FCOURT'),
      actions: [
        IconButton(
          onPressed: () => context.push('/health'),
          tooltip: 'Kiểm tra kết nối',
          icon: const Icon(Icons.wifi_tethering),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Ra sân. Hết mình.',
                style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Tìm sân yêu thích, kết nối đam mê thể thao.'),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: const CourtArtwork(
                  height: 210,
                  label: 'MỖI TRẬN ĐẤU · MỘT KẾT NỐI MỚI',
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _query,
                maxLength: 200,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Tên sân hoặc địa chỉ',
                  labelText: 'Bạn muốn chơi ở đâu?',
                  counterText: '',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Tìm sân',
                    onPressed: _search,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Khám phá theo môn',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SportFilters(
                onSelected: (sport) => context.push(
                  Uri(
                    path: '/branches',
                    queryParameters: {if (sport != null) 'sport': sport.name},
                  ).toString(),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.explore_outlined, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        'Sân mới, trải nghiệm mới',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Khám phá chi nhánh và khoảng giá phù hợp cho buổi chơi tiếp theo.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.push('/branches'),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Khám phá sân'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
