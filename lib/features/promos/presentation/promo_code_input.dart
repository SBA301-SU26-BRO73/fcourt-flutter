import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';

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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showApply = widget.onApply != null && !widget.applied;
    return Wp3bField(
      widget.applied ? 'Voucher đã áp dụng' : 'Mã khuyến mãi',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _code,
              readOnly: widget.readOnly || widget.applied,
              enabled: !widget.loading,
              maxLength: 50,
              textCapitalization: TextCapitalization.characters,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: widget.applied
                    ? 'Đã áp dụng mã khuyến mãi'
                    : 'Nhập mã khuyến mãi',
                counterText: '',
                errorText: widget.error,
                errorMaxLines: 4,
                helperText: widget.helperText,
                helperMaxLines: 3,
                errorStyle: TextStyle(color: colors.error),
                prefixIcon: Icon(
                  widget.applied
                      ? Icons.check_circle_outline
                      : Icons.local_offer_outlined,
                  color: widget.applied ? colors.primary : null,
                ),
              ),
            ),
          ),
          if (showApply) ...[
            const SizedBox(width: Gap.md),
            SizedBox(
              width: 112,
              child: Wp3bAction(
                'Áp dụng',
                busy: widget.loading,
                onPressed: widget.loading
                    ? null
                    : () => widget.onApply!(_code.text),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
