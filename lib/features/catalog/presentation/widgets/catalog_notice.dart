import 'package:flutter/material.dart';

import '../bloc/catalog_list_bloc.dart';
import '../messages.dart';

/// Hiện [notice] bằng snackbar: lỗi nền đỏ và đổi sang tiếng Việt nếu là lỗi BE đã biết.
void showCatalogNotice(BuildContext context, CatalogNotice notice) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          notice.isError ? CatalogMessages.localize(notice.message) : notice.message,
          style: notice.isError ? TextStyle(color: scheme.onError) : null,
        ),
        backgroundColor: notice.isError ? scheme.error : null,
      ),
    );
}
