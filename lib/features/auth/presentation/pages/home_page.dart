import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';
import '../../domain/entities/user_role.dart';
import '../bloc/auth_bloc.dart';

/// Trang chủ tạm theo vai trò. Mỗi vai trò sẽ được thay bằng màn hình thật khi feature
/// tương ứng hoàn thành.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static String titleFor(UserRole role) => switch (role) {
        UserRole.customer => 'Đặt sân',
        UserRole.staff => 'Vận hành chi nhánh',
        UserRole.admin => 'Quản lý cụm sân',
        UserRole.superAdmin => 'Quản trị hệ thống',
      };

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: Text(titleFor(user.role)),
        actions: [
          IconButton(
            tooltip: 'Tài khoản',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Xin chào, ${user.displayName}',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(user.role.label),
              if (user.role == UserRole.admin) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/admin/bookings'),
                  icon: const Icon(Icons.event_note),
                  label: const Text('Quản lý đơn đặt sân'),
                ),
              ],
              if (user.role == UserRole.superAdmin) ...[
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: () => context.push(AppRoutes.catalog),
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('Quản lý danh mục'),
                ),
              ],
              if (user.role == UserRole.customer) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.discover),
                  icon: const Icon(Icons.search),
                  label: const Text('Tìm sân'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
