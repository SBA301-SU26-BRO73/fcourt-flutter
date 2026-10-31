import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/court.dart';
import '../../domain/entities/court_type.dart';
import '../bloc/court_form_bloc.dart';
import '../widgets/facility_formatters.dart';

/// SCRUM-17: tạo/sửa sân. Lưu thành công thì `pop` kèm [Court] đã lưu.
class CourtFormScreen extends StatelessWidget {
  const CourtFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final editing = context.read<CourtFormBloc>().isEditing;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Sửa sân' : 'Thêm sân')),
      body: BlocConsumer<CourtFormBloc, CourtFormState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          if (state.status == CourtFormStatus.success && state.saved != null) {
            Navigator.of(context).pop(state.saved);
          } else if (state.status == CourtFormStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message ?? 'Lưu sân thất bại')),
            );
          }
        },
        buildWhen: (p, c) => _isLoadPhase(p.status) || _isLoadPhase(c.status),
        builder: (context, state) {
          switch (state.status) {
            case CourtFormStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case CourtFormStatus.loadFailure:
              return FacilityErrorView(
                message: state.message ?? 'Không tải được dữ liệu sân',
                onRetry: () =>
                    context.read<CourtFormBloc>().add(const CourtFormStarted()),
              );
            default:
              return _CourtForm(
                types: state.courtTypes,
                initial: state.initial,
              );
          }
        },
      ),
    );
  }
}

bool _isLoadPhase(CourtFormStatus status) =>
    status == CourtFormStatus.loading || status == CourtFormStatus.loadFailure;

class _CourtForm extends StatefulWidget {
  const _CourtForm({required this.types, this.initial});

  final List<CourtType> types;
  final Court? initial;

  @override
  State<_CourtForm> createState() => _CourtFormState();
}

class _CourtFormState extends State<_CourtForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _price = TextEditingController(
    text: widget.initial?.defaultPricePerHour.toString(),
  );
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late int? _typeId = widget.initial?.courtTypeId;
  late CourtStatus _status = widget.initial?.status ?? CourtStatus.active;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<CourtFormBloc>().add(
      CourtFormSubmitted(
        CourtDraft(
          name: _name.text,
          courtTypeId: _typeId!,
          description: _description.text,
          defaultPricePerHour: int.parse(_price.text),
          status: _status,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = [
      ...widget.types,
      // Giữ loại sân hiện tại nếu không có trong danh mục tạm thời.
      if (_typeId != null && widget.types.every((t) => t.id != _typeId))
        CourtType(id: _typeId!, name: 'Loại sân #$_typeId'),
    ];
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            key: const Key('court-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên sân *'),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Vui lòng nhập tên sân'
                : v.trim().length > 100
                ? 'Tên sân tối đa 100 ký tự'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const Key('court-type'),
            initialValue: _typeId,
            decoration: const InputDecoration(labelText: 'Loại sân *'),
            items: [
              for (final type in types)
                DropdownMenuItem(value: type.id, child: Text(type.name)),
            ],
            onChanged: (value) => setState(() => _typeId = value),
            validator: (v) => v == null ? 'Vui lòng chọn loại sân' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('court-price'),
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Giá mặc định mỗi giờ (VND) *',
              suffixText: 'đ/giờ',
            ),
            validator: (v) {
              final price = int.tryParse(v ?? '');
              if (price == null) return 'Vui lòng nhập giá';
              return price <= 0 ? 'Giá phải lớn hơn 0' : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Mô tả'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('court-form-maintenance'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Đang bảo trì'),
            subtitle: const Text('Khách không thể đặt sân khi đang bảo trì'),
            value: _status == CourtStatus.maintenance,
            onChanged: (value) => setState(
              () => _status = value
                  ? CourtStatus.maintenance
                  : CourtStatus.active,
            ),
          ),
          const SizedBox(height: 24),
          BlocBuilder<CourtFormBloc, CourtFormState>(
            buildWhen: (p, c) => p.status != c.status,
            builder: (context, state) {
              final busy = state.status == CourtFormStatus.submitting;
              return FilledButton.icon(
                key: const Key('court-submit'),
                onPressed: busy ? null : _submit,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  widget.initial == null ? 'Tạo sân' : 'Lưu thay đổi',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
