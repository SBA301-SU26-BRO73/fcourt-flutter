import 'package:dio/dio.dart';
import 'package:fcourt/features/auth/domain/entities/auth_user.dart';
import 'package:fcourt/features/auth/domain/entities/upload_document.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/domain/repositories/auth_repository.dart';
import 'package:fcourt/features/auth/presentation/services/document_picker.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const customerUser = AuthUser(
  id: 7,
  email: 'customer@demo.com',
  role: UserRole.customer,
  status: 'ACTIVE',
  fullName: 'An Nguyen',
  phone: '0909000001',
);

const adminUser = AuthUser(
  id: 9,
  email: 'owner@demo.com',
  role: UserRole.admin,
  status: 'ACTIVE',
  fullName: 'Chu San',
  phone: '0909000003',
);

/// JSON `AuthResponse` của auth-service (response phẳng, không có `data`).
Map<String, Object?> authResponseJson({
  String accessToken = 'access-1',
  String refreshToken = 'refresh-1',
  Map<String, Object?>? user,
}) =>
    {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': 'Bearer',
      'expiresIn': 900,
      'user': user ?? userJson(),
    };

Map<String, Object?> userJson({
  int id = 7,
  String email = 'customer@demo.com',
  String role = 'CUSTOMER',
  String status = 'ACTIVE',
}) =>
    {
      'id': id,
      'email': email,
      'fullName': 'An Nguyen',
      'phone': '0909000001',
      'role': role,
      'status': status,
      'createdAt': '2026-10-01T00:00:00Z',
    };

DioException dioError(int? status, {Object? body, DioExceptionType? type}) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    type: type ?? DioExceptionType.badResponse,
    response: status == null
        ? null
        : Response<dynamic>(requestOptions: request, statusCode: status, data: body),
  );
}

/// Bộ chọn tệp giả: trả lần lượt các danh sách đã định sẵn.
class FakeDocumentPicker implements DocumentPicker {
  FakeDocumentPicker(this._results);

  final List<List<UploadDocument>> _results;
  final List<bool> allowPdfCalls = [];

  @override
  Future<List<UploadDocument>> pick({required bool allowPdf}) async {
    allowPdfCalls.add(allowPdf);
    return _results.isEmpty ? const [] : _results.removeAt(0);
  }
}

const superAdminUser = AuthUser(
  id: 16,
  email: 'superadmin@demo.com',
  role: UserRole.superAdmin,
  status: 'ACTIVE',
  fullName: 'Quản Trị Hệ Thống',
  phone: '0939000001',
);
