import 'package:flutter/material.dart';

/// Hiển thị trong lúc app khôi phục phiên đăng nhập từ token đã lưu.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
