import 'package:flutter/material.dart';

import '../../../../app/widgets/fc_widgets.dart';

/// Hiển thị trong lúc app khôi phục phiên đăng nhập từ token đã lưu.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF4F3FE8),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 88),
            const SizedBox(height: Gap.xl),
            Text(
              'FCOURT',
              style: theme.textTheme.headlineSmall?.copyWith(
                letterSpacing: 4,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ra sân. Hết mình.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: Gap.xxl),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
