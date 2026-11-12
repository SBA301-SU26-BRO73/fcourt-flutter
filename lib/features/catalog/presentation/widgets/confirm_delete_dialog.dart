import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../app/widgets/wp3b_widgets.dart';

/// Hỏi xác nhận trước khi xóa. Trả `true` khi người dùng đồng ý.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Wp3bDialog(
      icon: Icons.delete_outline,
      tone: dialogContext.fc.danger,
      title: title,
      message: message,
      actions: [
        Wp3bAction(
          'Xóa',
          kind: Wp3bActionKind.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
        Wp3bAction(
          'Hủy',
          kind: Wp3bActionKind.text,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
