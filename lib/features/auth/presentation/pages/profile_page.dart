import '../../../../app/widgets/account_actions.dart';
import '../../domain/entities/user_role.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/change_password_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/submission_state.dart';
import '../messages.dart';
import '../validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/error_banner.dart';
import 'change_password_dialog.dart';

/// Xem và sửa họ tên, số điện thoại; email và vai trò chỉ xem. Có nút đăng xuất.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.editMode = false});
  final bool editMode;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    _fullName = TextEditingController(text: user?.fullName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final changed = await ChangePasswordDialog.show(
      context,
      context.read<ChangePasswordBloc>(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã đổi mật khẩu. Các thiết bị khác cần đăng nhập lại.',
          ),
        ),
      );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ProfileBloc>().add(
      ProfileSubmitted(fullName: _fullName.text, phone: _phone.text),
    );
  }

  Widget _hub(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const AccountBackButton(),
        title: const Text('Tài khoản'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: colors.primary,
                  child: Icon(Icons.person, color: colors.onPrimary, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Tài khoản',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(user?.email ?? '', overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => context.push('/profile/edit'),
                  child: const Text('Hồ sơ'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Tổng quát',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (user?.role == UserRole.customer) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lịch sử đặt sân'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/bookings'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lịch sử giao dịch'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/payments/history'),
            ),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cài đặt'),
            subtitle: const Text('Giao diện sáng, tối và theo hệ thống'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Đổi mật khẩu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePassword,
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (!widget.editMode) return _hub(context);
    return BlocConsumer<ProfileBloc, SubmissionState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final updated = state.user;
        if (state.status == SubmissionStatus.success && updated != null) {
          context.read<AuthBloc>().add(AuthUserUpdated(updated));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật thông tin')),
          );
        }
      },
      builder: (context, state) {
        final fieldErrors = AuthMessages.localizeAll(state.fieldErrors);
        return Scaffold(
          appBar: AppBar(
            leading: const AccountBackButton(),
            title: const Text('Hồ sơ'),
            actions: [
              IconButton(
                tooltip: 'Cài đặt',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(AppRoutes.settings),
              ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Thông tin cá nhân',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.mail_outline),
                          title: Text(user?.email ?? ''),
                          subtitle: Text(user?.role.label ?? ''),
                        ),
                        const SizedBox(height: 8),
                        if (state.status == SubmissionStatus.failure &&
                            fieldErrors.isEmpty) ...[
                          ErrorBanner(
                            AuthMessages.localize(state.message ?? ''),
                          ),
                          const SizedBox(height: 16),
                        ],
                        AuthTextField(
                          controller: _fullName,
                          label: 'Họ và tên',
                          validator: AuthValidators.fullName,
                          serverError: fieldErrors['fullName'],
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _phone,
                          label: 'Số điện thoại',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          validator: AuthValidators.phone,
                          serverError: fieldErrors['phone'],
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: state.isSubmitting ? null : _submit,
                          child: state.isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Lưu thay đổi'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _changePassword,
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Đổi mật khẩu'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => context.read<AuthBloc>().add(
                            const AuthLogoutRequested(),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Đăng xuất'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
