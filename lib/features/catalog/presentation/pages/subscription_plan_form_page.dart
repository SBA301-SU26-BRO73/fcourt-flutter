import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_plan_input.dart';
import '../bloc/catalog_form_bloc.dart';
import '../messages.dart';
import '../validators.dart';
import '../widgets/catalog_form_scaffold.dart';
import '../widgets/catalog_text_field.dart';
import '../widgets/form_error.dart';

/// Form tạo hoặc sửa gói dịch vụ SaaS. Lưu thành công thì đóng màn hình và trả `true`.
class SubscriptionPlanFormPage extends StatefulWidget {
  const SubscriptionPlanFormPage({super.key, this.editing});

  /// `null` khi tạo mới.
  final SubscriptionPlan? editing;

  @override
  State<SubscriptionPlanFormPage> createState() =>
      _SubscriptionPlanFormPageState();
}

class _SubscriptionPlanFormPageState extends State<SubscriptionPlanFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _tagline = TextEditingController(
    text: widget.editing?.tagline ?? '',
  );
  late final _monthly = TextEditingController(
    text: widget.editing?.monthlyPrice?.toString() ?? '',
  );
  late final _yearly = TextEditingController(
    text: widget.editing?.yearlyPrice?.toString() ?? '',
  );
  late final _maxBranches = TextEditingController(
    text: widget.editing?.maxBranches.toString() ?? '',
  );
  late final _maxCourts = TextEditingController(
    text: widget.editing?.maxCourts.toString() ?? '',
  );
  late final _features = TextEditingController(
    text: (widget.editing?.features ?? const []).join('\n'),
  );
  late final _color = TextEditingController(text: widget.editing?.color ?? '');
  late bool _popular = widget.editing?.popular ?? false;
  late bool _active = widget.editing?.active ?? true;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _tagline,
      _monthly,
      _yearly,
      _maxBranches,
      _maxCourts,
      _features,
      _color,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<CatalogFormBloc<SubscriptionPlanInput>>().add(
      CatalogFormSubmitted(
        SubscriptionPlanInput(
          name: _name.text.trim(),
          tagline: CatalogValidators.blankToNull(_tagline.text),
          monthlyPrice: CatalogValidators.parsePrice(_monthly.text),
          yearlyPrice: CatalogValidators.parsePrice(_yearly.text),
          maxBranches: int.parse(_maxBranches.text.trim()),
          maxCourts: int.parse(_maxCourts.text.trim()),
          features: CatalogValidators.parseFeatures(_features.text),
          color: CatalogValidators.blankToNull(_color.text),
          popular: _popular,
          active: _active,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    return BlocConsumer<
      CatalogFormBloc<SubscriptionPlanInput>,
      CatalogFormState
    >(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CatalogFormStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final fieldErrors = CatalogMessages.localizeAll(state.fieldErrors);
        final digitsOnly = [FilteringTextInputFormatter.digitsOnly];
        return CatalogFormScaffold(
          title: isEdit ? 'Sửa gói dịch vụ' : 'Thêm gói dịch vụ',
          subtitle: isEdit
              ? 'Cập nhật giá, giới hạn và tính năng của gói.'
              : 'Gói chủ sân có thể đăng ký trên bảng giá.',
          submitLabel: isEdit ? 'Lưu thay đổi' : 'Thêm gói dịch vụ',
          submitting: state.isSubmitting,
          onSubmit: _submit,
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
                  label: 'Tên gói',
                  validator: (v) =>
                      CatalogValidators.required(v, 'tên gói', max: 100),
                  serverError: fieldErrors['name'],
                ),
                const SizedBox(height: 16),
                CatalogTextField(
                  controller: _tagline,
                  label: 'Khẩu hiệu (không bắt buộc)',
                  validator: (v) =>
                      CatalogValidators.optionalText(v, 'Khẩu hiệu', 255),
                  serverError: fieldErrors['tagline'],
                ),
                const SizedBox(height: 16),
                CatalogTextField(
                  controller: _monthly,
                  label: 'Giá theo tháng (VND)',
                  helper: 'Để trống nếu không bán theo tháng',
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  validator: (v) =>
                      CatalogValidators.optionalPrice(v, 'Giá theo tháng'),
                  serverError: fieldErrors['monthlyPrice'],
                ),
                const SizedBox(height: 16),
                CatalogTextField(
                  controller: _yearly,
                  label: 'Giá theo năm (VND)',
                  helper: 'Để trống nếu không bán theo năm',
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  validator: (v) =>
                      CatalogValidators.optionalPrice(v, 'Giá theo năm'),
                  serverError: fieldErrors['yearlyPrice'],
                ),
                const SizedBox(height: 16),
                CatalogTextField(
                  controller: _maxBranches,
                  label: 'Số chi nhánh tối đa',
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  validator: (v) =>
                      CatalogValidators.positiveInt(v, 'Số chi nhánh'),
                  serverError: fieldErrors['maxBranches'],
                ),
                const SizedBox(height: 16),
                CatalogTextField(
                  controller: _maxCourts,
                  label: 'Số sân tối đa',
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  validator: (v) => CatalogValidators.positiveInt(v, 'Số sân'),
                  serverError: fieldErrors['maxCourts'],
                ),
                const SizedBox(height: 16),
                CatalogTextField(
                  controller: _features,
                  label: 'Tính năng (không bắt buộc)',
                  helper:
                      'Mỗi dòng một tính năng, tối đa ${CatalogValidators.maxFeatures}',
                  minLines: 4,
                  maxLines: 8,
                  validator: CatalogValidators.features,
                  serverError: fieldErrors['features'],
                ),
                const SizedBox(height: 16),
                CatalogTextField(
                  controller: _color,
                  label: 'Màu (không bắt buộc)',
                  helper: 'Ví dụ #0B7A4B',
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      CatalogValidators.optionalText(v, 'Màu', 20),
                  serverError: fieldErrors['color'],
                ),
                CatalogSwitchGroup(
                  children: [
                    SwitchListTile(
                      title: const Text('Gói phổ biến'),
                      subtitle: const Text('Làm nổi bật gói trên bảng giá'),
                      value: _popular,
                      onChanged: state.isSubmitting
                          ? null
                          : (v) => setState(() => _popular = v),
                    ),
                    SwitchListTile(
                      title: const Text('Đang bán'),
                      subtitle: const Text(
                        'Chỉ gói đang bán mới hiện cho chủ sân chọn',
                      ),
                      value: _active,
                      onChanged: state.isSubmitting
                          ? null
                          : (v) => setState(() => _active = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
