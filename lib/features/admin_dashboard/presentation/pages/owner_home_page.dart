import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/owner_todo_panel.dart';

/// Trang chủ của chủ sân (tab "Việc cần làm"): chỉ cuộn nội dung của
/// [OwnerTodoPanel], thanh điều hướng nổi do AppShell vẽ.
class OwnerHomePage extends StatelessWidget {
  const OwnerHomePage({
    super.key,
    required this.loader,
    this.onReceipts,
    this.onRefunds,
    this.onToday,
    this.onOverview,
    this.onNotifications,
    this.shortcuts = const [],
  });
  final OwnerTodoLoader loader;
  final void Function(int branchId)? onReceipts, onRefunds;
  final VoidCallback? onToday, onOverview, onNotifications;
  final List<OwnerShortcut> shortcuts;

  @override
  Widget build(BuildContext context) {
    final name = context.select(
      (AuthBloc bloc) => bloc.state.user?.displayName,
    );
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: OwnerTodoPanel(
                loader: loader,
                userName: _firstName(name),
                onReceipts: onReceipts,
                onRefunds: onRefunds,
                onToday: onToday,
                onOverview: onOverview,
                onNotifications: onNotifications,
                shortcuts: shortcuts,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Nguyễn Văn Minh" -> "Minh" (tên gọi cuối của người Việt).
  static String? _firstName(String? full) {
    final parts = (full ?? '').trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.last.isEmpty ? null : parts.last;
  }
}
