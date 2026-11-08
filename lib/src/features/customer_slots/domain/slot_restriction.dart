/// Optional public metadata proposed for SCRUM-111; availability stays separate.
class SlotRestriction {
  const SlotRestriction({
    required this.isPrivateEvent,
    this.publicReason,
    this.contactName,
    this.contactPhone,
  });
  final bool isPrivateEvent;
  final String? publicReason, contactName, contactPhone;

  Uri? get phoneUri {
    final phone = contactPhone?.trim();
    return phone != null && RegExp(r'^\+?[0-9]{9,15}$').hasMatch(phone)
        ? Uri(scheme: 'tel', path: phone)
        : null;
  }

  bool get hasContact => contactName != null || contactPhone != null;
}
