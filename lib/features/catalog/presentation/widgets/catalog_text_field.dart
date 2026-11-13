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

  /// WP3b: an 11px bold label above a soft rounded field (same as auth forms).
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        TextFormField(
          key: ValueKey('catalog-field-$label'),
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          minLines: minLines,
          maxLines: maxLines,
          textInputAction:
              textInputAction ??
              (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            helperText: helper,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            constraints: const BoxConstraints(minHeight: 49),
            errorText: serverError,
            errorMaxLines: 3,
          ),
        ),
      ],
    );
  }
}
