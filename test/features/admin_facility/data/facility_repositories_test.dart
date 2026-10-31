import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_facility/data/datasources/facility_remote_data_source.dart';
import 'package:fcourt/features/admin_facility/data/repositories/branch_repository_impl.dart';
import 'package:fcourt/features/admin_facility/data/repositories/court_repository_impl.dart';
import 'package:fcourt/features/admin_facility/data/repositories/slot_template_repository_impl.dart';
import 'package:fcourt/features/admin_facility/domain/entities/branch.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/court.dart';
import 'package:fcourt/features/admin_facility/domain/entities/slot_template.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_adapter.dart';
import '../fixtures.dart';

({FakeAdapter adapter, FacilityRemoteDataSource remote}) _remote(
  FakeHandler handler,
) {
  final adapter = FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://facility'))
    ..httpClientAdapter = adapter;
  return (adapter: adapter, remote: FacilityRemoteDataSource(dio));
}

const _draft = BranchDraft(
  name: '  FCourt Quận 7 ',
  address: '12 Nguyễn Hữu Thọ',
  ward: ' ',
  district: 'Quận 7',
  city: 'TP. Hồ Chí Minh',
  phone: '',
  openTime: ClockTime(6, 0),
  closeTime: ClockTime(22, 30),
  bankName: 'Vietcombank',
  bankBin: '970436',
  bankAccountNumber: '0123456789',
  bankAccountName: 'NGUYEN VAN A',
);

void main() {
  group('BranchRepositoryImpl', () {
    test('GET /api/admin/branches đổi BranchResponse[] thành entity', () async {
      final r = _remote(
        (_) => jsonResponse(200, [branchJson(), branchJson(id: 2)]),
      );

      final branches = await BranchRepositoryImpl(r.remote).getBranches();

      expect(r.adapter.requests.single.method, 'GET');
      expect(r.adapter.requests.single.path, '/api/admin/branches');
      expect(branches, hasLength(2));
      expect(branches.first, sampleBranch());
    });

    test(
      'POST tạo chi nhánh gửi đúng BranchRequest (HH:mm, bỏ chuỗi rỗng)',
      () async {
        final r = _remote((_) => jsonResponse(201, branchJson(id: 9)));

        final created = await BranchRepositoryImpl(r.remote)
            .createBranch(_draft);

        final request = r.adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/api/admin/branches');
        expect(request.data, {
          'name': 'FCourt Quận 7',
          'address': '12 Nguyễn Hữu Thọ',
          'ward': null,
          'district': 'Quận 7',
          'city': 'TP. Hồ Chí Minh',
          'phone': null,
          'openTime': '06:00',
          'closeTime': '22:30',
          'slotDurationMinutes': 30,
          'bankName': 'Vietcombank',
          'bankBin': '970436',
          'bankAccountNumber': '0123456789',
          'bankAccountName': 'NGUYEN VAN A',
        });
        expect(created.id, 9);
      },
    );

    test('PUT cập nhật và GET chi tiết dùng đúng đường dẫn', () async {
      final r = _remote((_) => jsonResponse(200, branchJson(id: 3)));
      final repo = BranchRepositoryImpl(r.remote);

      await repo.updateBranch(3, _draft);
      await repo.getBranch(3);

      expect(r.adapter.requests.map((o) => '${o.method} ${o.path}'), [
        'PUT /api/admin/branches/3',
        'GET /api/admin/branches/3',
      ]);
    });

    test('nhận giờ dạng HH:mm:ss', () async {
      final r = _remote(
        (_) => jsonResponse(200, {
          ...branchJson(),
          'openTime': '05:30:00',
          'closeTime': '23:00:00',
        }),
      );

      final branch = await BranchRepositoryImpl(r.remote).getBranch(1);

      expect(branch.openTime, const ClockTime(5, 30));
      expect(branch.closeTime, const ClockTime(23, 0));
    });

    test('400 ProblemDetail → ServerFailure mang detail', () async {
      final r = _remote(
        (_) => jsonResponse(400, {
          'type': 'about:blank',
          'title': 'Bad Request',
          'status': 400,
          'detail': 'closeTime phải sau openTime',
        }),
      );

      await expectLater(
        BranchRepositoryImpl(r.remote).createBranch(_draft),
        throwsA(
          const ServerFailure('closeTime phải sau openTime', statusCode: 400),
        ),
      );
    });

    test('403 vượt giới hạn gói → ServerFailure 403', () async {
      final r = _remote(
        (_) => jsonResponse(403, {
          'status': 403,
          'detail': 'Đã đạt số chi nhánh tối đa của gói',
        }),
      );

      await expectLater(
        BranchRepositoryImpl(r.remote).createBranch(_draft),
        throwsA(
          const ServerFailure(
            'Đã đạt số chi nhánh tối đa của gói',
            statusCode: 403,
          ),
        ),
      );
    });

    test('401 → UnauthorizedFailure', () async {
      final r = _remote((_) => jsonResponse(401, {'status': 401}));

      await expectLater(
        BranchRepositoryImpl(r.remote).getBranches(),
        throwsA(const UnauthorizedFailure()),
      );
    });

    test('JSON sai contract → UnknownFailure, không trả dữ liệu sai', () async {
      final r = _remote(
        (_) => jsonResponse(200, [
          {...branchJson(), 'openTime': '6h'},
        ]),
      );

      await expectLater(
        BranchRepositoryImpl(r.remote).getBranches(),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('CourtRepositoryImpl', () {
    test('GET sân theo chi nhánh, giá dạng số thực được làm tròn', () async {
      final r = _remote(
        (_) => jsonResponse(200, [
          courtJson(),
          courtJson(id: 6, status: 'MAINTENANCE'),
          courtJson(id: 7, status: 'INACTIVE'),
        ]),
      );

      final courts = await CourtRepositoryImpl(r.remote).getCourts(1);

      expect(r.adapter.requests.single.path, '/api/admin/branches/1/courts');
      expect(courts.first, sampleCourt());
      expect(courts.map((c) => c.status), [
        CourtStatus.active,
        CourtStatus.maintenance,
        CourtStatus.inactive,
      ]);
    });

    test('POST tạo sân gửi CourtRequest vào chi nhánh', () async {
      final r = _remote((_) => jsonResponse(201, courtJson(id: 8)));

      await CourtRepositoryImpl(r.remote).createCourt(
        1,
        const CourtDraft(
          name: ' Sân A ',
          courtTypeId: 3,
          description: '',
          defaultPricePerHour: 150000,
        ),
      );

      final request = r.adapter.requests.single;
      expect(
        '${request.method} ${request.path}',
        'POST /api/admin/branches/1/courts',
      );
      expect(request.data, {
        'name': 'Sân A',
        'courtTypeId': 3,
        'description': null,
        'defaultPricePerHour': 150000,
        'status': 'ACTIVE',
      });
    });

    test('PUT sửa sân và PATCH đổi trạng thái bảo trì', () async {
      final r = _remote(
        (_) => jsonResponse(200, courtJson(status: 'MAINTENANCE')),
      );
      final repo = CourtRepositoryImpl(r.remote);

      await repo.updateCourt(5, sampleCourt().toDraft());
      final updated = await repo.changeStatus(5, CourtStatus.maintenance);

      expect(r.adapter.requests.map((o) => '${o.method} ${o.path}'), [
        'PUT /api/admin/courts/5',
        'PATCH /api/admin/courts/5/status',
      ]);
      expect(r.adapter.requests.last.data, {'status': 'MAINTENANCE'});
      expect(updated.status, CourtStatus.maintenance);
    });

    test('trùng tên sân (400) → ServerFailure với detail', () async {
      final r = _remote(
        (_) => jsonResponse(400, {'detail': 'Tên sân đã tồn tại'}),
      );

      await expectLater(
        CourtRepositoryImpl(r.remote).createCourt(
          1,
          const CourtDraft(name: 'A', courtTypeId: 6, defaultPricePerHour: 1),
        ),
        throwsA(const ServerFailure('Tên sân đã tồn tại', statusCode: 400)),
      );
    });

    test('trạng thái lạ → UnknownFailure', () async {
      final r = _remote((_) => jsonResponse(200, courtJson(status: 'BROKEN')));

      await expectLater(
        CourtRepositoryImpl(r.remote).getCourt(5),
        throwsA(isA<UnknownFailure>()),
      );
    });

    test('loại sân tạm thời: Cầu lông 6, Pickleball 1, Tennis 3', () async {
      final types = await const CourtTypeRepositoryImpl().getCourtTypes();

      expect(
        {for (final t in types) t.name: t.id},
        {'Cầu lông': 6, 'Pickleball': 1, 'Tennis': 3},
      );
    });
  });

  group('SlotTemplateRepositoryImpl', () {
    test('POST apply-template gửi ApplyTemplateRequest', () async {
      final r = _remote(
        (_) => jsonResponse(200, {
          'courtId': 5,
          'daysOfWeek': [1, 2],
          'totalSlots': 64,
          'slots': <Object>[],
        }),
      );

      final applied = await SlotTemplateRepositoryImpl(r.remote).applyTemplate(
        5,
        const SlotTemplateRequest(
          startTime: ClockTime(6, 0),
          endTime: ClockTime(22, 0),
          price: 60000,
          daysOfWeek: [1, 2],
        ),
      );

      final request = r.adapter.requests.single;
      expect(
        '${request.method} ${request.path}',
        'POST /api/admin/courts/5/apply-template',
      );
      expect(request.data, {
        'startTime': '06:00',
        'endTime': '22:00',
        'durationMinutes': 30,
        'price': 60000,
        'daysOfWeek': [1, 2],
      });
      expect(
        applied,
        const AppliedTemplate(courtId: 5, daysOfWeek: [1, 2], totalSlots: 64),
      );
    });

    test('khoảng giờ ngoài giờ mở cửa (400) → ServerFailure', () async {
      final r = _remote(
        (_) => jsonResponse(400, {'detail': 'Ngoài giờ hoạt động'}),
      );

      await expectLater(
        SlotTemplateRepositoryImpl(r.remote).applyTemplate(
          5,
          const SlotTemplateRequest(
            startTime: ClockTime(5, 0),
            endTime: ClockTime(6, 0),
            price: 1,
          ),
        ),
        throwsA(const ServerFailure('Ngoài giờ hoạt động', statusCode: 400)),
      );
    });
  });
}
