import 'package:flutter/material.dart';

class AdminReceiptScreen extends StatefulWidget {
  const AdminReceiptScreen({super.key, required this.uri});
  final Uri uri;
  @override
  State<AdminReceiptScreen> createState() => _AdminReceiptScreenState();
}

class _AdminReceiptScreenState extends State<AdminReceiptScreen> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Biên lai thanh toán')),
    body: Center(
      child: InteractiveViewer(
        maxScale: 5,
        child: Image.network(
          widget.uri.toString(),
          key: ValueKey(_attempt),
          // Image loading is separate from the authenticated API Dio client.
          fit: BoxFit.contain,
          semanticLabel: 'Ảnh biên lai thanh toán',
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, _, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không tải được biên lai'),
              TextButton(
                onPressed: () => setState(() => _attempt++),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
