import 'package:flutter/material.dart';

import '../../domain/court_slot.dart';
import '../../domain/slot_restriction.dart';
import 'slot_contact_sheet.dart';

class SlotLockContacts extends StatelessWidget {
  const SlotLockContacts({super.key, required this.slots});
  final List<CourtSlot> slots;

  @override
  Widget build(BuildContext context) {
    final contacts = <(bool, String?, String?, String?), SlotRestriction>{};
    for (final slot in slots) {
      final contact = slot.restriction;
      if (slot.status == SlotStatus.outOfService &&
          contact != null &&
          contact.hasContact) {
        contacts[(
              contact.isPrivateEvent,
              contact.publicReason,
              contact.contactName,
              contact.contactPhone,
            )] =
            contact;
      }
    }
    if (contacts.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final contact in contacts.values)
          Card(
            child: ListTile(
              leading: Icon(
                contact.isPrivateEvent
                    ? Icons.celebration_outlined
                    : Icons.info_outline,
              ),
              title: Text(
                contact.isPrivateEvent ? 'Liên hệ sự kiện' : 'Liên hệ chủ sân',
              ),
              subtitle: Text(
                [
                  contact.contactName,
                  contact.contactPhone,
                ].whereType<String>().join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showModalBottomSheet<void>(
                useRootNavigator: true,
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => SlotContactSheet(contact: contact),
              ),
            ),
          ),
      ],
    );
  }
}
