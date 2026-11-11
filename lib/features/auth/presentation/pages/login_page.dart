import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';
import '../../../../app/widgets/fc_widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/login_bloc.dart';
import '../bloc/submission_state.dart';
import '../messages.dart';
import '../validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/error_banner.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<LoginBloc>().add(
      LoginSubmitted(email: _email.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, SubmissionState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final user = state.user;
        if (state.status == SubmissionStatus.success && user != null) {
          context.read<AuthBloc>().add(AuthSignedIn(user));
        }
      },
      builder: (context, state) {
        final fieldErrors = AuthMessages.localizeAll(state.fieldErrors);
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.screen,
                  vertical: Gap.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: BrandMark(size: 68),
                        ),
                        const SizedBox(height: Gap.xl),
                        const Eyebrow('FCOURT · RA SÂN. HẾT MÌNH.'),
                        const SizedBox(height: Gap.sm),
                        Text(
                          'Chào mừng đến FCOURT',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: Gap.sm),
                        Text(
                          'Đăng nhập để tiếp tục buổi chơi của bạn.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: Gap.xl),
                        FrostedCard(
                          padding: const EdgeInsets.all(Gap.screen),
                          radius: Radii.xl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (state.status == SubmissionStatus.failure) ...[
                                ErrorBanner(
                                  AuthMessages.localize(state.message ?? ''),
                                ),
                                const SizedBox(height: Gap.lg),
                              ],
                              AuthTextField(
                                controller: _email,
                                label: 'Email',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                validator: AuthValidators.email,
                                serverError: fieldErrors['email'],
                              ),
                              const SizedBox(height: Gap.lg),
                              AuthTextField(
                                controller: _password,
                                label: 'Mật khẩu',
                                icon: Icons.lock_outline_rounded,
                                obscure: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                validator: AuthValidators.loginPassword,
                                serverError: fieldErrors['password'],
                                onSubmitted: (_) => _submit(),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      context.push(AppRoutes.forgotPassword),
                                  child: const Text('Quên mật khẩu?'),
                                ),
                              ),
                              const SizedBox(height: Gap.xs),
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
                                    : const Text('Đăng nhập'),
                              ),
                              const SizedBox(height: Gap.lg),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Gap.md,
                                    ),
                                    child: Text(
                                      'hoặc',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: Gap.lg),
                              OutlinedButton(
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => context.read<LoginBloc>().add(
                                        const GoogleLoginSubmitted(),
                                      ),
                                child: const Text('Tiếp tục với Google'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gap.lg),
                        TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.registerCustomer),
                          child: const Text('Chưa có tài khoản? Đăng ký'),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.registerOwner),
                          child: const Text('Đăng ký làm chủ sân'),
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
