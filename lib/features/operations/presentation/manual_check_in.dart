import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/wp3b_widgets.dart';
import '../domain/manual_code.dart';
import '../domain/schedule.dart';
import 'check_in_dialog.dart';

class ManualCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final code = normalizeManualCode(newValue.text);
    final offset =
        (newValue.selection.extentOffset + (code.length - newValue.text.length))
            .clamp(0, code.length);
    return TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class ManualCheckIn extends StatefulWidget {
  const ManualCheckIn({super.key, required this.repository});
  final OperationsRepository repository;
  @override
  State<ManualCheckIn> createState() => _ManualCheckInState();
}

class _ManualCheckInState extends State<ManualCheckIn> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckInDialog(
        repository: widget.repository,
        code: normalizeManualCode(_code.text),
        manual: true,
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Wp3bDialog(
      icon: Icons.keyboard_alt_outlined,
      title: 'Nhập mã vé',
      message: 'Dùng mã trên vé khi không quét được QR.',
      content: Form(
        key: _form,
        child: Wp3bField(
          'Mã vé',
          child: TextFormField(
            controller: _code,
            autofocus: true,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            keyboardType: TextInputType.visiblePassword,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
            inputFormatters: [
              ManualCodeFormatter(),
              LengthLimitingTextInputFormatter(128),
            ],
            decoration: const InputDecoration(hintText: 'FC-89234'),
            validator: validateManualCode,
            onFieldSubmitted: (_) => _check(),
          ),
        ),
      ),
      actions: [
        Wp3bAction('Kiểm tra & Check-in', onPressed: _busy ? null : _check),
        Wp3bAction(
          'Hủy',
          kind: Wp3bActionKind.text,
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
