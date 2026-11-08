import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/slot_restriction.dart';

class SlotContactSheet extends StatefulWidget {
  const SlotContactSheet({super.key, required this.contact, this.launcher});
  final SlotRestriction contact;
  final Future<bool> Function(Uri)? launcher;
  @override
  State<SlotContactSheet> createState() => _SlotContactSheetState();
}

class _SlotContactSheetState extends State<SlotContactSheet> {
  bool _calling = false;
  Future<void> _call() async {
    final uri = widget.contact.phoneUri;
    if (uri == null || _calling) return;
    setState(() => _calling = true);
    var opened = false;
    try {
      opened =
          await (widget.launcher?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // The contact sheet stays usable when the device has no phone handler.
    }
    if (!mounted) return;
    setState(() => _calling = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa mở được ứng dụng gọi điện. Vui lòng thử lại.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                contact.isPrivateEvent ? 'Liên hệ sự kiện' : 'Liên hệ chủ sân',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (contact.publicReason != null) Text(contact.publicReason!),
              if (contact.contactName != null) Text(contact.contactName!),
              if (contact.contactPhone != null)
                SelectableText(contact.contactPhone!),
              const SizedBox(height: 16),
              if (contact.phoneUri != null)
                FilledButton.icon(
                  onPressed: _calling ? null : _call,
                  icon: const Icon(Icons.phone),
                  label: Text(
                    _calling
                        ? 'Đang mở cuộc gọi…'
                        : contact.isPrivateEvent
                        ? 'Gọi liên hệ sự kiện'
                        : 'Gọi chủ sân',
                  ),
                )
              else
                const Text('Chưa có số điện thoại hợp lệ để gọi.'),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
