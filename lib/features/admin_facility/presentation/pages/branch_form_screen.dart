import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/branch.dart';
import '../../domain/entities/branch_rules.dart';
import '../../domain/entities/clock_time.dart';
import '../../domain/entities/vietnam_province.dart';
import '../../domain/entities/vietqr_bank.dart';
import '../bloc/branch_form_bloc.dart';
import '../widgets/facility_formatters.dart';

/// SCRUM-15: tạo/sửa chi nhánh, gồm giờ mở cửa và tài khoản nhận VietQR.
/// Lưu thành công thì `pop` về màn trước kèm [Branch] đã lưu.
class BranchFormScreen extends StatelessWidget {
  const BranchFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final editing = context.read<BranchFormBloc>().isEditing;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Sửa chi nhánh' : 'Thêm chi nhánh')),
      body: BlocConsumer<BranchFormBloc, BranchFormState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == BranchFormStatus.success && state.saved != null) {
            Navigator.of(context).pop(state.saved);
          } else if (state.status == BranchFormStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message ?? 'Lưu thất bại')),
            );
          }
        },
        // Chỉ dựng lại khi đổi giữa tải dữ liệu và form, để không mất dữ liệu
        // người dùng đang nhập khi gửi form.
        buildWhen: (previous, current) =>
            _isLoadPhase(previous.status) || _isLoadPhase(current.status),
        builder: (context, state) {
          final bloc = context.read<BranchFormBloc>();
          switch (state.status) {
            case BranchFormStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case BranchFormStatus.loadFailure:
              return FacilityErrorView(
                message: state.message ?? 'Không tải được chi nhánh',
                onRetry: () => bloc.add(const BranchFormStarted()),
              );
            default:
              return _BranchForm(initial: state.initial);
          }
        },
      ),
    );
  }
}

bool _isLoadPhase(BranchFormStatus status) =>
    status == BranchFormStatus.loading ||
    status == BranchFormStatus.loadFailure;

class _BranchForm extends StatefulWidget {
  const _BranchForm({this.initial});

  final Branch? initial;

  @override
  State<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends State<_BranchForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _ward = TextEditingController(text: widget.initial?.ward);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _account = TextEditingController(
    text: widget.initial?.bankAccountNumber,
  );
  late final _accountName = TextEditingController(
    text: widget.initial?.bankAccountName,
  );

  late String? _city = _nonEmpty(widget.initial?.city);
  late String? _district = _nonEmpty(widget.initial?.district);
  late ClockTime _open = widget.initial?.openTime ?? const ClockTime(6, 0);
  late ClockTime _close = widget.initial?.closeTime ?? const ClockTime(22, 0);
  // Chi nhánh seed chỉ có bankName, chưa có bankBin: đoán theo tên ngân hàng.
  late String? _bankBin =
      _nonEmpty(widget.initial?.bankBin) ??
      VietQrBank.byName(widget.initial?.bankName)?.bin;

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _ward,
      _phone,
      _account,
      _accountName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Giữ được giá trị cũ của chi nhánh dù không nằm trong danh mục tĩnh.
  List<String> get _provinceOptions => [
    for (final p in VietnamProvince.all) p.name,
    if (_city != null && VietnamProvince.byName(_city) == null) _city!,
  ];

  List<String> get _districtOptions {
    final districts = VietnamProvince.byName(_city)?.districts ?? const [];
    return [
      ...districts,
      if (_district != null && !districts.contains(_district)) _district!,
    ];
  }

  Future<void> _pickTime({required bool open}) async {
    final picked = await pickClockTime(
      context,
      initial: open ? _open : _close,
      helpText: open ? 'Giờ mở cửa' : 'Giờ đóng cửa',
    );
    if (picked == null) return;
    setState(() => open ? _open = picked : _close = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final bank = VietQrBank.byBin(_bankBin);
    final draft = BranchDraft(
      name: _name.text,
      address: _address.text,
      ward: _ward.text,
      district: _district,
      city: _city!,
      // Form chưa sửa tọa độ/thời lượng slot nhưng PUT thay toàn bộ bản ghi.
      latitude: widget.initial?.latitude,
      longitude: widget.initial?.longitude,
      slotDurationMinutes: widget.initial?.slotDurationMinutes ?? 30,
      phone: _phone.text,
      openTime: _open,
      closeTime: _close,
      bankName: bank?.shortName ?? widget.initial?.bankName ?? '',
      bankBin: _bankBin!,
      bankAccountNumber: _account.text,
      bankAccountName: _accountName.text,
    );
    context.read<BranchFormBloc>().add(BranchFormSubmitted(draft));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Thông tin chi nhánh'),
          TextFormField(
            key: const Key('branch-name'),
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Tên chi nhánh *'),
            validator: (v) => BranchRules.required(
              v,
              'tên chi nhánh',
              max: BranchRules.maxName,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('branch-address'),
            controller: _address,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ (số nhà, đường) *',
            ),
            validator: (v) =>
                BranchRules.required(v, 'địa chỉ', max: BranchRules.maxAddress),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('branch-city'),
            initialValue: _city,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tỉnh/Thành phố *'),
            items: [
              for (final name in _provinceOptions)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) => setState(() {
              _city = value;
              _district = null;
            }),
            validator: (v) => v == null ? 'Vui lòng chọn tỉnh/thành' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // Đổi tỉnh thì dựng lại để xóa quận/huyện đã chọn.
            key: ValueKey('branch-district-$_city'),
            initialValue: _district,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Quận/Huyện'),
            items: [
              for (final name in _districtOptions)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) => setState(() => _district = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ward,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Phường/Xã'),
            validator: (v) => BranchRules.optional(
              v,
              'phường/xã',
              max: BranchRules.maxWardOrDistrict,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
            validator: BranchRules.phone,
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Giờ hoạt động'),
          FormField<void>(
            // Validator đọc trực tiếp _open/_close nên luôn đúng giờ mới nhất.
            validator: (_) => BranchRules.timeRange(_open, _close),
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        key: const Key('branch-open'),
                        label: 'Mở cửa',
                        time: _open,
                        onTap: () async {
                          await _pickTime(open: true);
                          field.didChange(null);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeTile(
                        key: const Key('branch-close'),
                        label: 'Đóng cửa',
                        time: _close,
                        onTap: () async {
                          await _pickTime(open: false);
                          field.didChange(null);
                        },
                      ),
                    ),
                  ],
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 12),
                    child: Text(
                      field.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Thanh toán VietQR'),
          DropdownButtonFormField<String>(
            key: const Key('branch-bank'),
            initialValue: _bankBin,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ngân hàng *'),
            items: [
              for (final bank in VietQrBank.all)
                DropdownMenuItem(
                  value: bank.bin,
                  child: Text('${bank.shortName} (${bank.bin})'),
                ),
              if (_bankBin != null && VietQrBank.byBin(_bankBin) == null)
                DropdownMenuItem(
                  value: _bankBin,
                  child: Text('${widget.initial?.bankName} ($_bankBin)'),
                ),
            ],
            onChanged: (value) => setState(() => _bankBin = value),
            validator: BranchRules.bankBin,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('branch-account'),
            controller: _account,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Số tài khoản *'),
            validator: BranchRules.accountNumber,
          ),
          const SizedBox(height: 4),
          TextFormField(
            key: const Key('branch-account-name'),
            controller: _accountName,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Tên chủ tài khoản *',
              helperText: 'Viết hoa không dấu như trên thẻ, ví dụ NGUYEN VAN A',
            ),
            validator: BranchRules.accountName,
          ),
          const SizedBox(height: 24),
          BlocBuilder<BranchFormBloc, BranchFormState>(
            buildWhen: (p, c) => p.status != c.status,
            builder: (context, state) {
              final busy = state.status == BranchFormStatus.submitting;
              return FilledButton.icon(
                key: const Key('branch-submit'),
                onPressed: busy ? null : _submit,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(editing ? 'Lưu thay đổi' : 'Tạo chi nhánh'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    super.key,
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final ClockTime time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.access_time),
      ),
      child: Text(time.format()),
    ),
  );
}
