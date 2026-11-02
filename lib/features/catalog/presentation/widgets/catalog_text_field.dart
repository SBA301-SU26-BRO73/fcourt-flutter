import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ô nhập của các form danh mục. [serverError] là lỗi validation do BE trả về cho field này.
class CatalogTextField extends StatelessWidget {
  const CatalogTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.serverError,
    this.helper,
    this.keyboardType,
    this.inputFormatters,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final String? serverError;
  final String? helper;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction ?? (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
        errorText: serverError,
        errorMaxLines: 3,
      ),
    );
  }
}
