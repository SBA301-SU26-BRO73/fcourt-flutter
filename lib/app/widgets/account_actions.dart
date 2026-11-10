import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountActions extends StatelessWidget {
  const AccountActions({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Cài đặt',
        onPressed: () => context.push('/settings'),
        icon: Icon(Icons.settings_outlined, color: color),
      ),
      IconButton(
        tooltip: 'Tài khoản',
        onPressed: () => context.push('/profile'),
        icon: Icon(Icons.account_circle_outlined, color: color),
      ),
    ],
  );
}

class AccountBackButton extends StatelessWidget {
  const AccountBackButton({super.key});
  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    },
  );
}
