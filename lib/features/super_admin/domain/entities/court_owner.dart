import 'package:equatable/equatable.dart';

/// Trạng thái tài khoản chủ sân theo auth-service (`users.status`).
enum OwnerStatus { pendingApproval, active, rejected, locked, inactive }

/// Loại giấy tờ đính kèm hồ sơ (`documents.docType`).
///
/// Backend chỉ có `LEGAL` (giấy phép kinh doanh / CCCD, chung một loại) và
/// `COURT_IMAGE`; chưa tách riêng CCCD.
enum OwnerDocumentType { legal, courtImage }

class OwnerDocument extends Equatable {
  const OwnerDocument({
    required this.id,
    required this.url,
    required this.type,
  });

  final int id;
  final Uri url;
  final OwnerDocumentType type;

  @override
  List<Object?> get props => [id, url, type];
}

/// Hồ sơ chủ sân (role ADMIN) mà SuperAdmin xét duyệt.
class CourtOwner extends Equatable {
  const CourtOwner({
    required this.id,
    required this.email,
    required this.fullName,
    required this.status,
    this.phone,
    this.createdAt,
    this.documents = const [],
  });

  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final OwnerStatus status;
  final DateTime? createdAt;
  final List<OwnerDocument> documents;

  bool get isPending => status == OwnerStatus.pendingApproval;

  List<OwnerDocument> get legalDocuments =>
      documents.where((d) => d.type == OwnerDocumentType.legal).toList();

  List<OwnerDocument> get courtImages =>
      documents.where((d) => d.type == OwnerDocumentType.courtImage).toList();

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    phone,
    status,
    createdAt,
    documents,
  ];
}
