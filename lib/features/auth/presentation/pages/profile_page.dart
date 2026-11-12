import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/account_actions.dart';
import '../../../../app/widgets/fc_widgets.dart';
import '../../../../app/widgets/wp3b_widgets.dart';
import '../../domain/entities/user_role.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const AccountBackButton(),
        title: const Text('Tài khoản'),
        actions: [
          CircleIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Cài đặt',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, Gap.xxl),
        children: [
          FcCard(
            radius: 22,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Text(
                    (user?.displayName.trim().isNotEmpty ?? false)
                        ? user!.displayName.trim()[0].toUpperCase()
                        : 'F',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Tài khoản',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (user != null) ...[
                        const SizedBox(height: 8),
                        TintTag(user.role.label),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Gap.sm),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => context.push('/profile/edit'),
                  child: const Text('Hồ sơ'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FcCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                if (user?.role == UserRole.customer) ...[
                  _AccountRow(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Lịch sử đặt sân',
                    onTap: () => context.go('/bookings'),
                  ),
                  const _RowDivider(),
                  _AccountRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Lịch sử giao dịch',
                    onTap: () => context.push('/payments/history'),
                  ),
                  const _RowDivider(),
                ],
                _AccountRow(
                  icon: Icons.palette_outlined,
                  title: 'Cài đặt',
                  onTap: () => context.push('/settings'),
                ),
                const _RowDivider(),
                _AccountRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'Đổi mật khẩu',
                  onTap: _changePassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FcCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _AccountRow(
              icon: Icons.logout_rounded,
              title: 'Đăng xuất',
              danger: true,
              onTap: () =>
                  context.read<AuthBloc>().add(const AuthLogoutRequested()),
            ),
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
              CircleIconButton(
                icon: Icons.settings_outlined,
                tooltip: 'Cài đặt',
                onPressed: () => context.push(AppRoutes.settings),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                              ?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.7,
                              ),
                        ),
                        const SizedBox(height: 14),
                        FcCard(
                          radius: 22,
                          child: Row(
                            children: [
                              Icon(
                                Icons.mail_outline,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.email ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      user?.role.label ?? '',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 17),
                        if (state.status == SubmissionStatus.failure &&
                            fieldErrors.isEmpty) ...[
                          ErrorBanner(
                            AuthMessages.localize(state.message ?? ''),
                          ),
                          const SizedBox(height: 17),
                        ],
                        AuthTextField(
                          controller: _fullName,
                          label: 'Họ và tên',
                          validator: AuthValidators.fullName,
                          serverError: fieldErrors['fullName'],
                        ),
                        const SizedBox(height: 17),
                        AuthTextField(
                          controller: _phone,
                          label: 'Số điện thoại',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          validator: AuthValidators.phone,
                          serverError: fieldErrors['phone'],
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 22),
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
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _changePassword,
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Đổi mật khẩu'),
                        ),
                        const SizedBox(height: 10),
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

/// One row of the account list: 42dp tinted circle icon, 13px title, chevron.
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = danger ? context.fc.danger : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tone?.container ?? colors.primaryContainer,
              ),
              child: Icon(
                icon,
                size: 20,
                color: tone?.color ?? colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tone?.color ?? colors.onSurface,
                ),
              ),
            ),
            if (!danger)
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 70, endIndent: 14);
}
