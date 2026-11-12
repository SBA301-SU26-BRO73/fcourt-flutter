import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/wp3b_widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/login_bloc.dart';
import '../bloc/submission_state.dart';
import '../messages.dart';
import '../validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/error_banner.dart';
import '../widgets/google_mark.dart';

/// WP3b mock-up screen 1: photo on top (323dp, 30dp lower corners, navy scrim),
/// then the form on the page background.
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
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _LoginPhoto(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 23, 24, 23),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Chào bạn trở lại',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.7,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Đăng nhập để tiếp tục đặt sân.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 21),
                            if (state.status == SubmissionStatus.failure) ...[
                              ErrorBanner(
                                AuthMessages.localize(state.message ?? ''),
                              ),
                              const SizedBox(height: 17),
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
                            const SizedBox(height: 17),
                            AuthTextField(
                              controller: _password,
                              label: 'Mật khẩu',
                              icon: Icons.lock_outline_rounded,
                              obscure: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              validator: AuthValidators.loginPassword,
                              serverError: fieldErrors['password'],
                              labelTrailing: InkWell(
                                onTap: () =>
                                    context.push(AppRoutes.forgotPassword),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    bottom: 0,
                                  ),
                                  child: Text(
                                    'Quên mật khẩu?',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: colors.primary,
                                        ),
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 17),
                            FilledButton(
                              style: _loginButton,
                              onPressed: state.isSubmitting ? null : _submit,
                              child: state.isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Đăng nhập'),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward, size: 18),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(child: Divider(height: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    'hoặc',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider(height: 1)),
                              ],
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton(
                              style: _loginButton,
                              onPressed: state.isSubmitting
                                  ? null
                                  : () => context.read<LoginBloc>().add(
                                      const GoogleLoginSubmitted(),
                                    ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GoogleMark(size: 20),
                                  SizedBox(width: 12),
                                  Text('Tiếp tục với Google'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: TextButton(
                                onPressed: () =>
                                    context.push(AppRoutes.registerCustomer),
                                child: Text.rich(
                                  TextSpan(
                                    text: 'Chưa có tài khoản? ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: colors.onSurface,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Đăng ký',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Mock-up buttons: 50dp tall, 12px label.
final _loginButton = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(48, 50)),
  textStyle: WidgetStatePropertyAll(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  ),
);

class _LoginPhoto extends StatelessWidget {
  const _LoginPhoto();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 323 + top,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              SportImages.onboarding,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -.1),
              excludeFromSemantics: true,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Color(0xB0102845), Color(0x00102845)],
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: top < 44 ? 53 : top + 9,
              child: Material(
                color: const Color(0xDFFFFFFF),
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('login-skip'),
                  onTap: () => context.push('/branches'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Text(
                      'Bỏ qua',
                      style: TextStyle(
                        color: Color(0xFF263451),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 24,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FCourt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 35,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Hẹn nhau trên sân.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
