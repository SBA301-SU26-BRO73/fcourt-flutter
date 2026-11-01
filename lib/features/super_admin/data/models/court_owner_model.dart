import '../../domain/entities/court_owner.dart';

/// Đọc `CourtAdminResponse` của auth-service. JSON sai contract ném
/// [FormatException] để repository đổi thành `Failure`.
class CourtOwnerModel {
  const CourtOwnerModel._();

  static CourtOwner fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('CourtAdminResponse không phải object');
    }
    final id = json['id'];
    final email = json['email'];
    final fullName = json['fullName'];
    final phone = json['phone'];
    final createdAt = json['createdAt'];
    final documents = json['documents'];
    if (id is! int || id <= 0) throw const FormatException('id không hợp lệ');
    if (email is! String || email.isEmpty) {
      throw const FormatException('email không hợp lệ');
    }
    if (fullName != null && fullName is! String) {
      throw const FormatException('fullName không hợp lệ');
    }
    if (phone != null && phone is! String) {
      throw const FormatException('phone không hợp lệ');
    }
    if (createdAt != null && createdAt is! String) {
      throw const FormatException('createdAt không hợp lệ');
    }
    if (documents != null && documents is! List) {
      throw const FormatException('documents không hợp lệ');
    }
    DateTime? created;
    if (createdAt is String) {
      created = DateTime.tryParse(createdAt);
      if (created == null) {
        throw const FormatException('createdAt không đúng ISO-8601');
      }
    }
    final name = fullName is String ? fullName.trim() : '';
    final phoneText = phone is String ? phone.trim() : '';
    return CourtOwner(
      id: id,
      email: email,
      fullName: name.isEmpty ? email : name,
      phone: phoneText.isEmpty ? null : phoneText,
      status: _status(json['status']),
      createdAt: created?.toLocal(),
      documents: [
        if (documents is List)
          for (final item in documents) _document(item),
      ],
    );
  }

  static OwnerStatus _status(Object? value) => switch (value) {
    'PENDING_APPROVAL' => OwnerStatus.pendingApproval,
    'ACTIVE' => OwnerStatus.active,
    'REJECTED' => OwnerStatus.rejected,
    'LOCKED' => OwnerStatus.locked,
    'INACTIVE' => OwnerStatus.inactive,
    _ => throw FormatException('status không hợp lệ: $value'),
  };

  static OwnerDocument _document(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('document không phải object');
    }
    final id = json['id'];
    final rawUrl = json['url'];
    final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (id is! int || id <= 0) {
      throw const FormatException('document.id không hợp lệ');
    }
    if (url == null ||
        !(url.scheme == 'https' || url.scheme == 'http') ||
        url.host.isEmpty) {
      throw const FormatException('document.url không hợp lệ');
    }
    final type = switch (json['docType']) {
      'LEGAL' => OwnerDocumentType.legal,
      'COURT_IMAGE' => OwnerDocumentType.courtImage,
      final other => throw FormatException('docType không hợp lệ: $other'),
    };
    return OwnerDocument(id: id, url: url, type: type);
  }
}
