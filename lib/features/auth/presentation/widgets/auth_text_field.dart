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

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
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
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        helperMaxLines: 2,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon),
        errorText: widget.serverError,
        errorMaxLines: 3,
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}
