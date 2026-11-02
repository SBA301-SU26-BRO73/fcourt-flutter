import 'package:flutter/material.dart';

class WaitingRipple extends StatefulWidget {
  const WaitingRipple({super.key});
  @override
  State<WaitingRipple> createState() => _WaitingRippleState();
}

class _WaitingRippleState extends State<WaitingRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đang chờ xác nhận thanh toán',
    child: SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 40 + 100 * ((_controller.value + i / 3) % 1),
                height: 40 + 100 * ((_controller.value + i / 3) % 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.2 * (1 - ((_controller.value + i / 3) % 1)),
                  ),
                ),
              ),
            Icon(
              Icons.receipt_long,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    ),
  );
}
