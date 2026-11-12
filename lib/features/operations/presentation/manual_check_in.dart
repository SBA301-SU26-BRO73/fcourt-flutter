import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    child: AlertDialog(
      title: const Text('Nhập mã vé'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Dùng mã trên vé khi không quét được QR.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                autofocus: true,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.visiblePassword,
                inputFormatters: [
                  ManualCodeFormatter(),
                  LengthLimitingTextInputFormatter(128),
                ],
                decoration: const InputDecoration(
                  labelText: 'Mã vé',
                  hintText: 'FC-89234',
                ),
                validator: validateManualCode,
                onFieldSubmitted: (_) => _check(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _check,
          child: const Text('Kiểm tra & Check-in'),
        ),
      ],
    ),
  );
}
