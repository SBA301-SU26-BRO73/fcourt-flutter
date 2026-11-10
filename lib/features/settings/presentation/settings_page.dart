import '../../../app/widgets/account_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_redirect.dart';
import '../../../app/theme/theme_controller.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const AccountBackButton(),
        title: const Text('Cài đặt'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Theo cách của bạn',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text('Tùy chỉnh giao diện và quản lý tài khoản FCOURT.'),
                const SizedBox(height: 28),
                Text(
                  'GIAO DIỆN',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.palette_outlined),
                          title: Text('Chế độ hiển thị'),
                          subtitle: Text('Áp dụng cho toàn bộ ứng dụng.'),
                        ),
                        const SizedBox(height: 12),
                        for (final (mode, title, subtitle, icon) in [
                          (
                            ThemeMode.system,
                            'Theo hệ thống',
                            'Tự động theo cài đặt thiết bị',
                            Icons.brightness_auto_outlined,
                          ),
                          (
                            ThemeMode.light,
                            'Sáng',
                            'Rõ ràng, nhẹ nhàng vào ban ngày',
                            Icons.light_mode_outlined,
                          ),
                          (
                            ThemeMode.dark,
                            'Tối',
                            'Dịu mắt khi sử dụng buổi tối',
                            Icons.dark_mode_outlined,
                          ),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Semantics(
                              selected: theme.mode == mode,
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                tileColor: theme.mode == mode
                                    ? colors.primaryContainer
                                    : null,
                                leading: Icon(icon),
                                title: Text(title),
                                subtitle: Text(subtitle),
                                trailing: Icon(
                                  theme.mode == mode
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: colors.primary,
                                ),
                                onTap: () async {
                                  final saved = await theme.select(mode);
                                  if (!saved && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Đã đổi giao diện nhưng chưa lưu được. Vui lòng chọn lại để thử.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'TÀI KHOẢN',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(user?.displayName ?? 'Tài khoản'),
                        subtitle: Text(user?.role.label ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.profile),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Thông tin và bảo mật'),
                        subtitle: const Text(
                          'Cập nhật hồ sơ, số điện thoại, mật khẩu',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.profile),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Center(child: Text('FCOURT · Ra sân. Hết mình.')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
