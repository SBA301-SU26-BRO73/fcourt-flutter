import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';
import '../../domain/entities/upload_document.dart';
import '../bloc/register_bloc.dart';
import '../bloc/submission_state.dart';
import '../messages.dart';
import '../services/document_picker.dart';
import '../validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/error_banner.dart';

/// Đăng ký chủ sân: gửi kèm giấy tờ pháp lý (bắt buộc) và ảnh sân (tùy chọn),
/// sau đó chờ quản trị viên duyệt mới đăng nhập được.
class RegisterOwnerPage extends StatefulWidget {
  const RegisterOwnerPage({super.key, required this.picker});

  final DocumentPicker picker;

  static const maxLegalDocuments = 5;
  static const maxCourtImages = 10;

  @override
  State<RegisterOwnerPage> createState() => _RegisterOwnerPageState();
}

class _RegisterOwnerPageState extends State<RegisterOwnerPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final List<UploadDocument> _legal = [];
  final List<UploadDocument> _images = [];
  bool _legalMissing = false;

  @override
  void dispose() {
    for (final controller in [_fullName, _email, _phone, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(List<UploadDocument> target, int max, bool allowPdf) async {
    final picked = await widget.picker.pick(allowPdf: allowPdf);
    setState(() {
      for (final document in picked) {
        final duplicate = target.any((d) => d.path == document.path);
        if (!duplicate && target.length < max) target.add(document);
      }
      _legalMissing = _legal.isEmpty && _legalMissing;
    });
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    setState(() => _legalMissing = _legal.isEmpty);
    if (!formValid || _legal.isEmpty) return;
    context.read<RegisterBloc>().add(
          OwnerRegistrationSubmitted(
            fullName: _fullName.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text,
            legalDocuments: List.unmodifiable(_legal),
            courtImages: List.unmodifiable(_images),
          ),
        );
  }

  Future<void> _showSubmitted() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đã gửi hồ sơ'),
        content: const Text(
          'Hồ sơ của bạn đang chờ quản trị viên duyệt. '
          'Bạn có thể đăng nhập sau khi hồ sơ được chấp nhận.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Về màn hình đăng nhập'),
          ),
        ],
      ),
    );
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBloc, SubmissionState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == SubmissionStatus.success) _showSubmitted();
      },
      builder: (context, state) {
        final fieldErrors = AuthMessages.localizeAll(state.fieldErrors);
        final knownFields = {'fullName', 'email', 'phone', 'password', 'legalDocuments', 'courtImages'};
        final showBanner = state.status == SubmissionStatus.failure &&
            !fieldErrors.keys.any(knownFields.contains);
        return Scaffold(
          appBar: AppBar(title: const Text('Đăng ký chủ sân')),
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
                        if (showBanner) ...[
                          ErrorBanner(AuthMessages.localize(state.message ?? '')),
                          const SizedBox(height: 16),
                        ],
                        AuthTextField(
                          controller: _fullName,
                          label: 'Họ và tên chủ sân',
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
                        ),
                        const SizedBox(height: 24),
                        _DocumentSection(
                          title: 'Giấy tờ pháp lý (bắt buộc)',
                          hint: 'Giấy phép kinh doanh, CCCD. Ảnh hoặc PDF, mỗi tệp tối đa 5 MB.',
                          addLabel: 'Chọn giấy tờ',
                          documents: _legal,
                          maxCount: RegisterOwnerPage.maxLegalDocuments,
                          error: _legalMissing
                              ? 'Vui lòng chọn ít nhất 1 giấy tờ pháp lý'
                              : fieldErrors['legalDocuments'],
                          onAdd: () => _pick(
                            _legal,
                            RegisterOwnerPage.maxLegalDocuments,
                            true,
                          ),
                          onRemove: (document) =>
                              setState(() => _legal.remove(document)),
                        ),
                        const SizedBox(height: 16),
                        _DocumentSection(
                          title: 'Ảnh sân (không bắt buộc)',
                          hint: 'Ảnh thực tế của cụm sân để quản trị viên tham khảo.',
                          addLabel: 'Chọn ảnh sân',
                          documents: _images,
                          maxCount: RegisterOwnerPage.maxCourtImages,
                          error: fieldErrors['courtImages'],
                          onAdd: () => _pick(
                            _images,
                            RegisterOwnerPage.maxCourtImages,
                            false,
                          ),
                          onRemove: (document) =>
                              setState(() => _images.remove(document)),
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
                              : const Text('Gửi hồ sơ đăng ký'),
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

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.title,
    required this.hint,
    required this.addLabel,
    required this.documents,
    required this.maxCount,
    required this.onAdd,
    required this.onRemove,
    this.error,
  });

  final String title;
  final String hint;
  final String addLabel;
  final List<UploadDocument> documents;
  final int maxCount;
  final String? error;
  final VoidCallback onAdd;
  final ValueChanged<UploadDocument> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(hint, style: theme.textTheme.bodySmall),
        for (final document in documents)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(document.name, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Bỏ tệp ${document.name}',
              icon: const Icon(Icons.close),
              onPressed: () => onRemove(document),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: documents.length >= maxCount ? null : onAdd,
            icon: const Icon(Icons.add),
            label: Text('$addLabel (${documents.length}/$maxCount)'),
          ),
        ),
      ],
    );
  }
}
