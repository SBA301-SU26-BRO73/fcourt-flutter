import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/court_type.dart';
import '../../domain/entities/court_type_input.dart';
import '../bloc/catalog_form_bloc.dart';
import '../messages.dart';
import '../validators.dart';
import '../widgets/catalog_text_field.dart';
import '../widgets/form_error.dart';

/// Form tạo hoặc sửa loại sân. Lưu thành công thì đóng màn hình và trả `true`.
class CourtTypeFormPage extends StatefulWidget {
  const CourtTypeFormPage({super.key, this.editing});

  /// `null` khi tạo mới.
  final CourtType? editing;

  @override
  State<CourtTypeFormPage> createState() => _CourtTypeFormPageState();
}

class _CourtTypeFormPageState extends State<CourtTypeFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _nameEn = TextEditingController(text: widget.editing?.nameEn ?? '');
  late final _description = TextEditingController(text: widget.editing?.description ?? '');
  late final _icon = TextEditingController(text: widget.editing?.icon ?? '');
  late final _color = TextEditingController(text: widget.editing?.color ?? '');
  late bool _active = widget.editing?.active ?? true;

  @override
  void dispose() {
    for (final controller in [_name, _nameEn, _description, _icon, _color]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<CatalogFormBloc<CourtTypeInput>>().add(
          CatalogFormSubmitted(
            CourtTypeInput(
              name: _name.text.trim(),
              nameEn: CatalogValidators.blankToNull(_nameEn.text),
              description: CatalogValidators.blankToNull(_description.text),
              icon: CatalogValidators.blankToNull(_icon.text),
              color: CatalogValidators.blankToNull(_color.text),
              active: _active,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    return BlocConsumer<CatalogFormBloc<CourtTypeInput>, CatalogFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CatalogFormStatus.success) Navigator.of(context).pop(true);
      },
      builder: (context, state) {
        final fieldErrors = CatalogMessages.localizeAll(state.fieldErrors);
        return Scaffold(
          appBar: AppBar(title: Text(isEdit ? 'Sửa loại sân' : 'Thêm loại sân')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.status == CatalogFormStatus.failure &&
                        fieldErrors.isEmpty) ...[
                      FormError(CatalogMessages.localize(state.message ?? '')),
                      const SizedBox(height: 16),
                    ],
                    CatalogTextField(
                      controller: _name,
                      label: 'Tên loại sân',
                      validator: (v) => CatalogValidators.required(v, 'tên loại sân', max: 100),
                      serverError: fieldErrors['name'],
                    ),
                    const SizedBox(height: 16),
                    CatalogTextField(
                      controller: _nameEn,
                      label: 'Tên tiếng Anh (không bắt buộc)',
                      validator: (v) => CatalogValidators.optionalText(v, 'Tên tiếng Anh', 100),
                      serverError: fieldErrors['nameEn'],
                    ),
                    const SizedBox(height: 16),
                    CatalogTextField(
                      controller: _description,
                      label: 'Mô tả (không bắt buộc)',
                      minLines: 3,
                      maxLines: 5,
                      validator: (v) => CatalogValidators.optionalText(v, 'Mô tả', 2000),
                      serverError: fieldErrors['description'],
                    ),
                    const SizedBox(height: 16),
                    CatalogTextField(
                      controller: _icon,
                      label: 'Biểu tượng (không bắt buộc)',
                      validator: (v) => CatalogValidators.optionalText(v, 'Biểu tượng', 50),
                      serverError: fieldErrors['icon'],
                    ),
                    const SizedBox(height: 16),
                    CatalogTextField(
                      controller: _color,
                      label: 'Màu (không bắt buộc)',
                      helper: 'Ví dụ #0B7A4B',
                      textInputAction: TextInputAction.done,
                      validator: (v) => CatalogValidators.optionalText(v, 'Màu', 20),
                      serverError: fieldErrors['color'],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đang hoạt động'),
                      subtitle: const Text('Chủ sân chỉ chọn được loại sân đang hoạt động'),
                      value: _active,
                      onChanged: state.isSubmitting ? null : (v) => setState(() => _active = v),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: state.isSubmitting ? null : _submit,
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEdit ? 'Lưu thay đổi' : 'Thêm loại sân'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
