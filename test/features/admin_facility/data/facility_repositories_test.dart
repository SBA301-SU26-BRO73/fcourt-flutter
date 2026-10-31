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

/// ProblemDetail đúng như ApiErrors của facility-service trả về.
Map<String, dynamic> _problem(
  int status,
  String detail, {
  List<String>? errors,
}) => {
  'type': 'about:blank',
  'title': switch (status) {
    400 => 'Bad Request',
    403 => 'Forbidden',
    404 => 'Not Found',
    409 => 'Conflict',
    _ => 'Error',
  },
  'status': status,
  'detail': detail,
  'instance': '/api/admin/branches',
  'errors': ?errors,
};

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
      'chi nhánh seed SQL (district, tọa độ, bankBin null) vẫn đọc được',
      () async {
        final r = _remote(
          (_) => jsonResponse(200, [branchJson(), seededBranchJson()]),
        );

        final seeded = (await BranchRepositoryImpl(
          r.remote,
        ).getBranches()).last;

        expect(seeded.district, isNull);
        expect(seeded.latitude, isNull);
        expect(seeded.bankBin, '');
        expect(seeded.bankName, 'MB Bank');
        expect(seeded.fullAddress, 'Số 101 Đặng Văn Ngữ, Trung Tự, Hà Nội');
      },
    );

    test('POST tạo chi nhánh gửi đúng BranchRequest (HH:mm, bỏ chuỗi rỗng, '
        'không gửi status)', () async {
      final r = _remote((_) => jsonResponse(201, branchJson(id: 9)));

      final created = await BranchRepositoryImpl(r.remote).createBranch(_draft);

      final request = r.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/admin/branches');
      expect(request.data, {
        'name': 'FCourt Quận 7',
        'address': '12 Nguyễn Hữu Thọ',
        'ward': null,
        'district': 'Quận 7',
        'city': 'TP. Hồ Chí Minh',
        'latitude': null,
        'longitude': null,
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
    });

    test(
      'PUT giữ tọa độ và thời lượng slot cũ (backend thay toàn bộ)',
      () async {
        final r = _remote(
          (_) => jsonResponse(200, {
            ...branchJson(id: 3),
            'slotDurationMinutes': 60,
          }),
        );
        final repo = BranchRepositoryImpl(r.remote);

        final branch = await repo.getBranch(3);
        await repo.updateBranch(3, branch.toDraft());

        expect(r.adapter.requests.map((o) => '${o.method} ${o.path}'), [
          'GET /api/admin/branches/3',
          'PUT /api/admin/branches/3',
        ]);
        final body = r.adapter.requests.last.data as Map<String, dynamic>;
        expect(body['latitude'], 10.732912);
        expect(body['longitude'], 106.721133);
        expect(body['slotDurationMinutes'], 60);
        expect(body.containsKey('status'), isFalse);
      },
    );

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

    test('400 validation → liệt kê lỗi từng trường của `errors`', () async {
      final r = _remote(
        (_) => jsonResponse(
          400,
          _problem(
            400,
            'Invalid request fields',
            errors: [
              'bankAccountNumber: must be 6-20 digits',
              'closeTime must be after openTime',
            ],
          ),
        ),
      );

      await expectLater(
        BranchRepositoryImpl(r.remote).createBranch(_draft),
        throwsA(
          const ServerFailure(
            'Dữ liệu chưa hợp lệ: bankAccountNumber: must be 6-20 digits; '
            'closeTime must be after openTime',
            statusCode: 400,
            errors: [
              'bankAccountNumber: must be 6-20 digits',
              'closeTime must be after openTime',
            ],
          ),
        ),
      );
    });

    test(
      '403 vượt giới hạn gói → thông báo tiếng Việt kèm số giới hạn',
      () async {
        final r = _remote(
          (_) => jsonResponse(
            403,
            _problem(403, 'Branch limit of your subscription plan reached (3)'),
          ),
        );

        await expectLater(
          BranchRepositoryImpl(r.remote).createBranch(_draft),
          throwsA(
            const ServerFailure(
              'Đã đạt số chi nhánh tối đa của gói dịch vụ (3)',
              statusCode: 403,
            ),
          ),
        );
      },
    );

    test(
      '404 (chi nhánh của chủ sân khác) → thông báo không có quyền',
      () async {
        final r = _remote(
          (_) => jsonResponse(404, _problem(404, 'Branch not found')),
        );

        await expectLater(
          BranchRepositoryImpl(r.remote).getBranch(99),
          throwsA(
            isA<ServerFailure>()
                .having((f) => f.statusCode, 'statusCode', 404)
                .having(
                  (f) => f.message,
                  'message',
                  contains('không thuộc quyền quản lý của bạn'),
                ),
          ),
        );
      },
    );

    test('401 → UnauthorizedFailure', () async {
      final r = _remote((_) => jsonResponse(401, _problem(401, 'expired')));

      await expectLater(
        BranchRepositoryImpl(r.remote).getBranches(),
        throwsA(const UnauthorizedFailure()),
      );
    });

    test('JSON sai contract → UnknownFailure, không trả dữ liệu sai', () async {
      for (final bad in [
        {...branchJson(), 'openTime': '6h'},
        {...branchJson(), 'status': 'DELETED'},
        {...branchJson(), 'city': null},
      ]) {
        final r = _remote((_) => jsonResponse(200, [bad]));

        await expectLater(
          BranchRepositoryImpl(r.remote).getBranches(),
          throwsA(isA<UnknownFailure>()),
        );
      }
    });
  });

  group('CourtRepositoryImpl', () {
    test(
      'GET sân theo chi nhánh, giá BigDecimal (120000.00) làm tròn',
      () async {
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
      },
    );

    test(
      'sân seed SQL có defaultPricePerHour null vẫn hiển thị được',
      () async {
        final r = _remote(
          (_) => jsonResponse(200, [
            seededCourtJson(),
            seededCourtJson(id: 4),
            courtJson(branchId: 4),
          ]),
        );

        final courts = await CourtRepositoryImpl(r.remote).getCourts(4);

        expect(courts, hasLength(3));
        expect(courts.first.defaultPricePerHour, isNull);
        expect(
          courts.first.imageUrl,
          startsWith('https://images.unsplash.com'),
        );
        expect(courts.first.description, 'Sân tiêu chuẩn ngoài trời');
        expect(courts.last.defaultPricePerHour, 120000);
      },
    );

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
        'imageUrl': null,
        'defaultPricePerHour': 150000,
        'status': 'ACTIVE',
      });
    });

    test(
      'PUT gửi lại imageUrl hiện có; PATCH đổi trạng thái bảo trì',
      () async {
        final r = _remote(
          (_) => jsonResponse(200, courtJson(status: 'MAINTENANCE')),
        );
        final repo = CourtRepositoryImpl(r.remote);

        await repo.updateCourt(
          5,
          const CourtDraft(
            name: 'Sân số 2',
            courtTypeId: 1,
            imageUrl: 'https://img/court.jpg',
            defaultPricePerHour: 90000,
            status: CourtStatus.active,
          ),
        );
        final updated = await repo.changeStatus(5, CourtStatus.maintenance);

        expect(r.adapter.requests.map((o) => '${o.method} ${o.path}'), [
          'PUT /api/admin/courts/5',
          'PATCH /api/admin/courts/5/status',
        ]);
        expect(
          (r.adapter.requests.first.data as Map)['imageUrl'],
          'https://img/court.jpg',
        );
        expect(r.adapter.requests.last.data, {'status': 'MAINTENANCE'});
        expect(updated.status, CourtStatus.maintenance);
      },
    );

    test('trùng tên sân (400) → thông báo tiếng Việt', () async {
      final r = _remote(
        (_) => jsonResponse(
          400,
          _problem(400, 'Court name already exists in this branch'),
        ),
      );

      await expectLater(
        CourtRepositoryImpl(r.remote).createCourt(1, sampleCourtDraft),
        throwsA(
          const ServerFailure(
            'Tên sân đã tồn tại trong chi nhánh',
            statusCode: 400,
          ),
        ),
      );
    });

    test('403 giới hạn sân, 404 sân của chủ khác', () async {
      var status = 403;
      final r = _remote(
        (_) => status == 403
            ? jsonResponse(
                403,
                _problem(
                  403,
                  'Court limit of your subscription plan reached (15)',
                ),
              )
            : jsonResponse(404, _problem(404, 'Court not found')),
      );
      final repo = CourtRepositoryImpl(r.remote);

      await expectLater(
        repo.createCourt(1, sampleCourtDraft),
        throwsA(
          const ServerFailure(
            'Đã đạt số sân tối đa của gói dịch vụ (15)',
            statusCode: 403,
          ),
        ),
      );
      status = 404;
      await expectLater(
        repo.changeStatus(77, CourtStatus.maintenance),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'status', 404),
        ),
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
    test(
      'POST apply-template gửi ApplyTemplateRequest, đọc ApplyResponse',
      () async {
        final r = _remote(
          (_) => jsonResponse(200, {
            'courtId': 5,
            'daysOfWeek': [1, 2],
            'totalSlots': 2,
            'slots': [
              {
                'id': 101,
                'courtId': 5,
                'dayOfWeek': 1,
                'startTime': '06:00',
                'endTime': '06:30',
                'price': 60000.0,
                'active': true,
              },
              {
                'id': 102,
                'courtId': 5,
                'dayOfWeek': 2,
                'startTime': '06:00',
                'endTime': '06:30',
                'price': 60000.0,
                'active': true,
              },
            ],
          }),
        );

        final applied = await SlotTemplateRepositoryImpl(r.remote)
            .applyTemplate(
              5,
              const SlotTemplateRequest(
                startTime: ClockTime(6, 0),
                endTime: ClockTime(6, 30),
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
          'endTime': '06:30',
          'durationMinutes': 30,
          'price': 60000,
          'daysOfWeek': [1, 2],
        });
        expect(
          applied,
          const AppliedTemplate(courtId: 5, daysOfWeek: [1, 2], totalSlots: 2),
        );
      },
    );

    test('ngoài giờ mở cửa (400) và trùng slot (409) → tiếng Việt', () async {
      var status = 400;
      final r = _remote(
        (_) => status == 400
            ? jsonResponse(
                400,
                _problem(400, 'Slots must be within branch hours 06:00-22:00'),
              )
            : jsonResponse(
                409,
                _problem(409, 'Slot overlaps an existing template slot'),
              ),
      );
      final repo = SlotTemplateRepositoryImpl(r.remote);
      const request = SlotTemplateRequest(
        startTime: ClockTime(5, 0),
        endTime: ClockTime(6, 0),
        price: 1,
      );

      await expectLater(
        repo.applyTemplate(5, request),
        throwsA(
          const ServerFailure(
            'Khung giờ phải nằm trong giờ mở cửa của chi nhánh (06:00-22:00)',
            statusCode: 400,
          ),
        ),
      );
      status = 409;
      await expectLater(
        repo.applyTemplate(5, request),
        throwsA(
          const ServerFailure(
            'Khung giờ trùng với mẫu khung giờ đang có',
            statusCode: 409,
          ),
        ),
      );
    });
  });
}
