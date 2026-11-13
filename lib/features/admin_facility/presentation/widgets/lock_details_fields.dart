import 'package:flutter/material.dart';

import '../../../../app/widgets/filter_pill.dart';
import '../../../admin_dashboard/presentation/widgets/owner_ui.dart';
import '../../domain/entities/court_lock.dart';

/// Giữ nội dung form khóa dùng chung cho lịch tuần (SCRUM-50) và màn bao sân
/// (SCRUM-112), để hai nơi gửi đúng cùng một contract.
class LockDetailsEditor extends ChangeNotifier {
  LockDetailsEditor([this._type = LockType.outOfService]);

  static final _phone = RegExp(r'^\+?[0-9]{9,15}$');

  final reason = TextEditingController();
  final notes = TextEditingController();
  final publicReason = TextEditingController();
  final contactName = TextEditingController();
  final contactPhone = TextEditingController();
  LockType _type;
  bool _showErrors = false;

  LockType get type => _type;

  void refresh() => notifyListeners();
  bool get showErrors => _showErrors;

  set type(LockType value) {
    if (value == _type) return;
    _type = value;
    notifyListeners();
  }

  String? get reasonError {
    final text = reason.text.trim();
    if (text.isEmpty) return 'Nhập lý do khóa';
    if (text.length > 500) return 'Tối đa 500 ký tự';
    return null;
  }

  String? get phoneError {
    final text = contactPhone.text.trim();
    if (text.isEmpty) return null;
    return _phone.hasMatch(text) ? null : 'Số điện thoại gồm 9-15 chữ số';
  }

  String? get publicReasonError =>
      publicReason.text.trim().length > 500 ? 'Tối đa 500 ký tự' : null;

  String? get contactNameError =>
      contactName.text.trim().length > 100 ? 'Tối đa 100 ký tự' : null;

  String? get notesError =>
      notes.text.trim().length > 1000 ? 'Tối đa 1000 ký tự' : null;

  bool get valid =>
      reasonError == null &&
      phoneError == null &&
      publicReasonError == null &&
      contactNameError == null &&
      notesError == null;

  /// Trả về `null` (và hiện lỗi từng ô) khi form chưa hợp lệ.
  LockDetails? build() {
    _showErrors = true;
    notifyListeners();
    if (!valid) return null;
    String? clean(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return LockDetails(
      type: _type,
      reason: reason.text.trim(),
      notes: clean(notes),
      publicReason: clean(publicReason),
      contactName: clean(contactName),
      contactPhone: clean(contactPhone),
    );
  }

  @override
  void dispose() {
    reason.dispose();
    notes.dispose();
    publicReason.dispose();
    contactName.dispose();
    contactPhone.dispose();
    super.dispose();
  }
}

class LockDetailsFields extends StatelessWidget {
  const LockDetailsFields({super.key, required this.editor});

  final LockDetailsEditor editor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) {
        final show = editor.showErrors;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OwnerField(
              label: 'Loại khóa',
              child: Wrap(
                key: const Key('lock-type'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in LockType.values)
                    FilterPill(
                      type.label,
                      selected: editor.type == type,
                      onTap: () => editor.type = type,
                    ),
                ],
              ),
            ),
            OwnerField(
              label: 'Lý do (chỉ chủ sân thấy) *',
              child: TextField(
                key: const Key('lock-reason'),
                controller: editor.reason,
                maxLength: 500,
                style: ownerInputText,
                decoration: ownerInput(
                  hint: 'Sửa sàn, bảo trì…',
                  error: show ? editor.reasonError : null,
                ),
                onChanged: (_) => editor.refresh(),
              ),
            ),
            OwnerField(
              label: 'Ghi chú nội bộ',
              child: TextField(
                key: const Key('lock-notes'),
                controller: editor.notes,
                maxLines: 2,
                style: ownerInputText,
                decoration: ownerInput(error: show ? editor.notesError : null),
              ),
            ),
            const OwnerSectionTitle('Hiển thị cho khách (tùy chọn)', top: 6),
            OwnerField(
              label: 'Nội dung công khai',
              child: TextField(
                key: const Key('lock-public-reason'),
                controller: editor.publicReason,
                style: ownerInputText,
                decoration: ownerInput(
                  error: show ? editor.publicReasonError : null,
                ),
              ),
            ),
            OwnerField(
              label: 'Người liên hệ',
              child: TextField(
                key: const Key('lock-contact-name'),
                controller: editor.contactName,
                style: ownerInputText,
                decoration: ownerInput(
                  error: show ? editor.contactNameError : null,
                ),
              ),
            ),
            OwnerField(
              label: 'Số điện thoại liên hệ',
              child: TextField(
                key: const Key('lock-contact-phone'),
                controller: editor.contactPhone,
                keyboardType: TextInputType.phone,
                style: ownerInputText,
                decoration: ownerInput(error: show ? editor.phoneError : null),
              ),
            ),
          ],
        );
      },
    );
  }
}
