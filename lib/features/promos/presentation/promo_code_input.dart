import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

class PromoCodeInput extends StatefulWidget {
  const PromoCodeInput({
    super.key,
    this.initialCode = '',
    this.onChanged,
    this.onApply,
    this.loading = false,
    this.applied = false,
    this.readOnly = false,
    this.error,
    this.helperText,
  });
  final String initialCode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onApply;
  final bool loading, applied, readOnly;
  final String? error, helperText;
  @override
  State<PromoCodeInput> createState() => _PromoCodeInputState();
}

class _PromoCodeInputState extends State<PromoCodeInput> {
  late final _code = TextEditingController(
    text: widget.applied ? '' : widget.initialCode,
  );
  @override
  void didUpdateWidget(PromoCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.applied && !oldWidget.applied) _code.clear();
    if (widget.initialCode != oldWidget.initialCode && !widget.applied) {
      _code.text = widget.initialCode;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _code,
        readOnly: widget.readOnly || widget.applied,
        enabled: !widget.loading,
        maxLength: 50,
        textCapitalization: TextCapitalization.characters,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: widget.applied ? 'Voucher đã áp dụng' : 'Mã khuyến mãi',
          counterText: '',
          errorText: widget.error,
          errorMaxLines: 4,
          helperText: widget.helperText,
          helperMaxLines: 3,
          errorStyle: TextStyle(color: Theme.of(context).colorScheme.error),
          prefixIcon: Icon(
            widget.applied
                ? Icons.check_circle_outline
                : Icons.local_offer_outlined,
          ),
        ),
      ),
      if (widget.onApply != null && !widget.applied)
        const SizedBox(height: Gap.sm),
      if (widget.onApply != null && !widget.applied)
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: widget.loading
                ? null
                : () => widget.onApply!(_code.text),
            child: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Áp dụng'),
          ),
        ),
    ],
  );
}
