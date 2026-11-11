import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/register_bloc.dart';
import '../bloc/submission_state.dart';
import '../messages.dart';
import '../validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/error_banner.dart';

class RegisterCustomerPage extends StatefulWidget {
  const RegisterCustomerPage({super.key});

  @override
  State<RegisterCustomerPage> createState() => _RegisterCustomerPageState();
}

class _RegisterCustomerPageState extends State<RegisterCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_fullName, _email, _phone, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<RegisterBloc>().add(
      CustomerRegistrationSubmitted(
        fullName: _fullName.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBloc, SubmissionState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final user = state.user;
        if (state.status == SubmissionStatus.success && user != null) {
          context.read<AuthBloc>().add(AuthSignedIn(user));
        }
      },
      builder: (context, state) {
        final fieldErrors = AuthMessages.localizeAll(state.fieldErrors);
        return Scaffold(
          appBar: AppBar(title: const Text('Đăng ký khách hàng')),
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
                          controller: _email,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          validator: AuthValidators.email,
                          serverError: fieldErrors['email'],
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _phone,
                          label: 'Số điện thoại',
                          keyboardType: TextInputType.phone,
                          validator: AuthValidators.phone,
                          serverError: fieldErrors['phone'],
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _password,
                          label: 'Mật khẩu',
                          obscure: true,
                          validator: AuthValidators.password,
                          serverError: fieldErrors['password'],
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _confirm,
                          label: 'Nhập lại mật khẩu',
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          validator: AuthValidators.confirmPassword(
                            () => _password.text,
                          ),
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
                              : const Text('Đăng ký'),
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
