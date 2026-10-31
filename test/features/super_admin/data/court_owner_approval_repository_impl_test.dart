import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/super_admin/data/datasources/super_admin_remote_data_source.dart';
import 'package:fcourt/features/super_admin/data/repositories/court_owner_approval_repository_impl.dart';
import 'package:fcourt/features/super_admin/domain/entities/court_owner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_adapter.dart';

Map<String, Object?> ownerJson({
  int id = 7,
  String status = 'PENDING_APPROVAL',
  List<Object?>? documents,
}) => {
  'id': id,
  'email': 'owner$id@fcourt.vn',
  'fullName': 'Chủ sân $id',
  'phone': '0901234567',
  'role': 'ADMIN',
  'status': status,
  'createdAt': '2026-10-30T08:15:00Z',
  'documents':
      documents ??
      [
        {
          'id': 11,
          'url': 'https://cdn.fcourt.vn/legal.jpg',
          'docType': 'LEGAL',
        },
        {
          'id': 12,
          'url': 'https://cdn.fcourt.vn/court.jpg',
          'docType': 'COURT_IMAGE',
        },
      ],
};

({CourtOwnerApprovalRepositoryImpl repo, FakeAdapter adapter}) build(
  FakeHandler handler,
) {
  final adapter = FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://auth.test'))
    ..httpClientAdapter = adapter;
  return (
    repo: CourtOwnerApprovalRepositoryImpl(SuperAdminRemoteDataSource(dio)),
    adapter: adapter,
  );
}

void main() {
  group('pendingOwners', () {
    test('GET đúng đường dẫn và chỉ giữ hồ sơ PENDING_APPROVAL', () async {
      final t = build(
        (_) => jsonResponse(200, [
          ownerJson(id: 1),
          ownerJson(id: 2, status: 'ACTIVE'),
          ownerJson(id: 3),
        ]),
      );

      final owners = await t.repo.pendingOwners();

      expect(t.adapter.requests.single.method, 'GET');
      expect(
        t.adapter.requests.single.path,
        '/api/super-admin/court-admins/pending',
      );
      expect(owners.map((o) => o.id), [1, 3]);
      expect(owners.every((o) => o.isPending), isTrue);
    });

    test('đổi JSON thành entity kèm giấy tờ theo loại', () async {
      final t = build((_) => jsonResponse(200, [ownerJson()]));

      final owner = (await t.repo.pendingOwners()).single;

      expect(owner.email, 'owner7@fcourt.vn');
      expect(owner.fullName, 'Chủ sân 7');
      expect(owner.phone, '0901234567');
      expect(owner.createdAt, DateTime.utc(2026, 10, 30, 8, 15).toLocal());
      expect(owner.legalDocuments.single.url.toString(), contains('legal'));
      expect(owner.courtImages.single.id, 12);
    });

    test('response không phải mảng thành UnknownFailure', () async {
      final t = build((_) => jsonResponse(200, {'content': []}));

      await expectLater(
        t.repo.pendingOwners(),
        throwsA(
          const UnknownFailure(
            CourtOwnerApprovalRepositoryImpl.invalidDataMessage,
          ),
        ),
      );
    });

    test('docType lạ hoặc URL không phải http(s) thành UnknownFailure', () {
      for (final doc in [
        {'id': 1, 'url': 'https://cdn/x.jpg', 'docType': 'SELFIE'},
        {'id': 1, 'url': 'file:///sdcard/x.jpg', 'docType': 'LEGAL'},
      ]) {
        final t = build(
          (_) => jsonResponse(200, [
            ownerJson(documents: [doc]),
          ]),
        );
        expect(t.repo.pendingOwners(), throwsA(isA<UnknownFailure>()));
      }
    });
  });

  test('ownerDetail GET theo id', () async {
    final t = build((_) => jsonResponse(200, ownerJson(id: 9)));

    final owner = await t.repo.ownerDetail(9);

    expect(t.adapter.requests.single.path, '/api/super-admin/court-admins/9');
    expect(owner.id, 9);
  });

  group('approve', () {
    test('PUT /approve không gửi reason khi bỏ trống', () async {
      final t = build((_) => jsonResponse(200, ownerJson(status: 'ACTIVE')));

      final owner = await t.repo.approve(7);

      final request = t.adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/api/super-admin/court-admins/7/approve');
      expect(request.data, <String, Object?>{});
      expect(owner.status, OwnerStatus.active);
    });

    test('gửi reason khi có ghi chú', () async {
      final t = build((_) => jsonResponse(200, ownerJson(status: 'ACTIVE')));

      await t.repo.approve(7, reason: 'Giấy tờ hợp lệ');

      expect(t.adapter.requests.single.data, {'reason': 'Giấy tờ hợp lệ'});
    });

    test('response vẫn PENDING thì báo chưa xác minh được kết quả', () async {
      final t = build((_) => jsonResponse(200, ownerJson()));

      await expectLater(
        t.repo.approve(7),
        throwsA(
          const UnknownFailure(
            CourtOwnerApprovalRepositoryImpl.unverifiedMessage,
          ),
        ),
      );
    });
  });

  test('reject PUT /reject với reason', () async {
    final t = build((_) => jsonResponse(200, ownerJson(status: 'REJECTED')));

    final owner = await t.repo.reject(7, 'Ảnh CCCD mờ');

    final request = t.adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/api/super-admin/court-admins/7/reject');
    expect(request.data, {'reason': 'Ảnh CCCD mờ'});
    expect(owner.status, OwnerStatus.rejected);
  });

  group('ánh xạ lỗi ProblemDetail', () {
    Map<String, Object?> problem(int status, String detail) => {
      'type': 'about:blank',
      'title': 'Error',
      'status': status,
      'detail': detail,
    };

    final cases = <int, Failure>{
      401: const UnauthorizedFailure(),
      403: const ServerFailure(
        'Tài khoản không có quyền SuperAdmin',
        statusCode: 403,
      ),
      404: const ServerFailure('Không tìm thấy hồ sơ chủ sân', statusCode: 404),
      409: const ServerFailure(
        'Hồ sơ đã được xử lý. Vui lòng tải lại danh sách.',
        statusCode: 409,
      ),
      400: const ServerFailure('reason: không được để trống', statusCode: 400),
      500: const ServerFailure('Lỗi máy chủ (500)', statusCode: 500),
    };
    cases.forEach((status, expected) {
      test('$status → $expected', () async {
        final t = build(
          (_) => jsonResponse(
            status,
            problem(status, 'reason: không được để trống'),
          ),
        );
        await expectLater(t.repo.reject(7, 'x'), throwsA(expected));
      });
    });

    test('400 không có detail dùng thông điệp mặc định', () async {
      final t = build((_) => jsonResponse(400, {'status': 400}));
      await expectLater(
        t.repo.approve(7),
        throwsA(
          const ServerFailure('Thông tin duyệt chưa hợp lệ', statusCode: 400),
        ),
      );
    });

    test('lỗi kết nối thành NetworkFailure', () async {
      final t = build(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        ),
      );
      await expectLater(
        t.repo.pendingOwners(),
        throwsA(const NetworkFailure()),
      );
    });
  });
}
