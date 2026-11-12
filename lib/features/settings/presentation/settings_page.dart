import '../../../app/widgets/account_actions.dart';
import '../../../app/widgets/fc_widgets.dart';

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
              padding: const EdgeInsets.all(Gap.screen),
              children: [
                Text(
                  'Chế độ hiển thị',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Gap.md),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Theo hệ thống'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Sáng')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Tối')),
                  ],
                  selected: {theme.mode},
                  onSelectionChanged: (selection) async {
                    final saved = await theme.select(selection.first);
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
                const SizedBox(height: Gap.xl),
                Text('Tài khoản', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Gap.md),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(user?.displayName ?? 'Tài khoản'),
                    subtitle: Text(user?.role.label ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.profile),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
