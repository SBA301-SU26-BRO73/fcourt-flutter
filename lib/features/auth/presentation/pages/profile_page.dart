import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  const ProfilePage({super.key});

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
          content: Text('Đã đổi mật khẩu. Các thiết bị khác cần đăng nhập lại.'),
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

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
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
          appBar: AppBar(title: const Text('Tài khoản')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.mail_outline),
                          title: Text(user?.email ?? ''),
                          subtitle: Text(user?.role.label ?? ''),
                        ),
                        const SizedBox(height: 8),
                        if (state.status == SubmissionStatus.failure &&
                            fieldErrors.isEmpty) ...[
                          ErrorBanner(AuthMessages.localize(state.message ?? '')),
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                          onPressed: () =>
                              context.read<AuthBloc>().add(const AuthLogoutRequested()),
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
