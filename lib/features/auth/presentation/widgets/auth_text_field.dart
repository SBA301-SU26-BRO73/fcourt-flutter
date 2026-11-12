import 'package:flutter/material.dart';

/// Ô nhập của các form auth. [serverError] là lỗi validation do BE trả về cho field này.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.serverError,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.obscure = false,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.icon,
    this.helperText,
    this.labelTrailing,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final String? serverError;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Optional leading icon.
  final IconData? icon;

  /// Luật nhập hiện sẵn dưới ô (ví dụ độ dài tối thiểu của mật khẩu).
  final String? helperText;

  /// Small action on the label line (e.g. "Quên mật khẩu?").
  final Widget? labelTrailing;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  /// WP3b mock-up: an 11px bold label sits above a 49dp soft field.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (widget.labelTrailing != null) widget.labelTrailing!,
            ],
          ),
        ),
        TextFormField(
          key: ValueKey('auth-field-${widget.label}'),
          controller: widget.controller,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          // Kiểm tra khi người dùng rời ô hoặc sửa, lỗi cũ tự mất khi sửa đúng.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            helperText: widget.helperText,
            helperMaxLines: 2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            constraints: const BoxConstraints(minHeight: 49),
            prefixIcon: widget.icon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 12),
                    child: Icon(widget.icon, size: 18),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            errorText: widget.serverError,
            errorMaxLines: 3,
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    iconSize: 18,
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
