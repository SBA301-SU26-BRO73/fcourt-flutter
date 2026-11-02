import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/core/network/auth_interceptor.dart';
import 'package:fcourt/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:fcourt/features/catalog/data/models/court_type_model.dart';
import 'package:fcourt/features/catalog/data/models/subscription_plan_model.dart';
import 'package:fcourt/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:fcourt/features/catalog/domain/entities/court_type.dart';
import 'package:fcourt/features/catalog/domain/entities/court_type_input.dart';
import 'package:fcourt/features/catalog/domain/entities/subscription_plan_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_adapter.dart';
import '../../auth/helpers.dart' show dioError;
import '../helpers.dart';

class MockRemote extends Mock implements CatalogRemoteDataSource {}

void main() {
  group('models', () {
    test('CourtTypeModel đọc đủ trường và đổi sang entity', () {
      final model = CourtTypeModel.fromJson(courtTypeJson());

      expect(
        model.toEntity(),
        const CourtType(
          id: 1,
          name: 'Cầu lông',
          active: true,
          nameEn: 'Badminton',
          color: '#0B7A4B',
        ),
      );
    });

    test('CourtTypeModel: trường tùy chọn thiếu thì là null, active mặc định true', () {
      final model = CourtTypeModel.fromJson({'id': 3, 'name': 'Tennis'});

      expect(model.nameEn, isNull);
      expect(model.active, isTrue);
    });

    test('CourtTypeModel.requestBody gửi đủ các trường, trường rỗng là null', () {
      expect(
        CourtTypeModel.requestBody(const CourtTypeInput(name: 'Cầu lông', active: false)),
        {
          'name': 'Cầu lông',
          'nameEn': null,
          'description': null,
          'icon': null,
          'color': null,
          'active': false,
        },
      );
    });

    test('SubscriptionPlanModel đọc giá null (không bán) và danh sách tính năng', () {
      final model = SubscriptionPlanModel.fromJson(
        planJson(monthlyPrice: null, yearlyPrice: 1990000, features: ['A', 'B']),
      );

      final plan = model.toEntity();
      expect(plan.monthlyPrice, isNull);
      expect(plan.yearlyPrice, 1990000);
      expect(plan.features, ['A', 'B']);
      expect(plan.maxBranches, 1);
      expect(plan.maxCourts, 5);
    });

    test('SubscriptionPlanModel.requestBody gửi đủ các trường', () {
      expect(
        SubscriptionPlanModel.requestBody(
          const SubscriptionPlanInput(
            name: 'Cơ bản',
            maxBranches: 1,
            maxCourts: 5,
            monthlyPrice: 199000,
            features: ['A'],
            popular: true,
          ),
        ),
        {
          'name': 'Cơ bản',
          'tagline': null,
          'monthlyPrice': 199000,
          'yearlyPrice': null,
          'maxBranches': 1,
          'maxCourts': 5,
          'features': ['A'],
          'color': null,
          'popular': true,
          'active': true,
        },
      );
    });
  });

  group('CatalogRemoteDataSource', () {
    late FakeAdapter adapter;
    late CatalogRemoteDataSource remote;

    void useResponse(FakeHandler handler) {
      adapter = FakeAdapter(handler);
      remote = CatalogRemoteDataSource(
        Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
      );
    }

    test('courtTypes gọi GET kèm page và size rồi đọc Page của BE', () async {
      useResponse(
        (_) => jsonResponse(
          200,
          pageJson([courtTypeJson(), courtTypeJson(id: 2, name: 'Bóng đá mini')],
              page: 1, totalPages: 3, totalElements: 45),
        ),
      );

      final page = await remote.courtTypes(1, 20);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/court-types');
      expect(request.queryParameters, {'page': 1, 'size': 20});
      expect(request.extra.containsKey(AuthInterceptor.skipAuthKey), isFalse);
      expect(page.items.map((m) => m.name), ['Cầu lông', 'Bóng đá mini']);
      expect(page.page, 1);
      expect(page.totalPages, 3);
      expect(page.totalElements, 45);
      expect(page.hasMore, isTrue);
    });

    test('Page thiếu trường thì coi như rỗng thay vì lỗi', () async {
      useResponse((_) => jsonResponse(200, <String, Object?>{}));

      final page = await remote.plans(0, 20);

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('createCourtType dùng POST, updateCourtType dùng PUT theo id', () async {
      useResponse((_) => jsonResponse(200, courtTypeJson()));

      await remote.createCourtType(const CourtTypeInput(name: 'Cầu lông'));
      await remote.updateCourtType(7, const CourtTypeInput(name: 'Cầu lông'));

      expect(adapter.requests[0].method, 'POST');
      expect(adapter.requests[0].path, '/api/court-types');
      expect(adapter.requests[1].method, 'PUT');
      expect(adapter.requests[1].path, '/api/court-types/7');
      expect((adapter.requests[1].data as Map)['name'], 'Cầu lông');
    });

    test('deleteCourtType dùng DELETE theo id', () async {
      useResponse((_) => ResponseBody.fromString('', 204));

      await remote.deleteCourtType(5);

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/api/court-types/5');
    });

    test('gói dịch vụ: GET danh sách, POST tạo, PUT sửa, DELETE xóa', () async {
      useResponse((options) {
        if (options.method == 'GET') return jsonResponse(200, pageJson([planJson()]));
        if (options.method == 'DELETE') return ResponseBody.fromString('', 204);
        return jsonResponse(200, planJson());
      });
      const input = SubscriptionPlanInput(name: 'Cơ bản', maxBranches: 1, maxCourts: 5);

      final page = await remote.plans(0, 20);
      await remote.createPlan(input);
      await remote.updatePlan(3, input);
      await remote.deletePlan(3);

      expect(page.items.single.name, 'Cơ bản');
      expect(
        adapter.requests.map((r) => '${r.method} ${r.path}'),
        [
          'GET /api/subscription-plans',
          'POST /api/subscription-plans',
          'PUT /api/subscription-plans/3',
          'DELETE /api/subscription-plans/3',
        ],
      );
      expect((adapter.requests[1].data as Map)['maxBranches'], 1);
    });
  });

  group('CatalogRepositoryImpl', () {
    late MockRemote remote;
    late CatalogRepositoryImpl repository;

    setUpAll(() {
      registerFallbackValue(const CourtTypeInput(name: 'fallback'));
      registerFallbackValue(
        const SubscriptionPlanInput(name: 'fallback', maxBranches: 1, maxCourts: 1),
      );
    });

    setUp(() {
      remote = MockRemote();
      repository = CatalogRepositoryImpl(remote);
    });

    test('courtTypes đổi model sang entity và giữ thông tin trang', () async {
      when(() => remote.courtTypes(0, 20)).thenAnswer(
        (_) async => pageOf([CourtTypeModel.fromJson(courtTypeJson())], totalPages: 2),
      );

      final page = await repository.courtTypes(page: 0, size: 20);

      expect(page.items.single.name, 'Cầu lông');
      expect(page.hasMore, isTrue);
    });

    test('saveCourtType không có id thì tạo, có id thì sửa', () async {
      const input = CourtTypeInput(name: 'Cầu lông');
      when(() => remote.createCourtType(input))
          .thenAnswer((_) async => CourtTypeModel.fromJson(courtTypeJson()));
      when(() => remote.updateCourtType(4, input))
          .thenAnswer((_) async => CourtTypeModel.fromJson(courtTypeJson(id: 4)));

      final created = await repository.saveCourtType(input);
      final updated = await repository.saveCourtType(input, id: 4);

      expect(created.id, 1);
      expect(updated.id, 4);
      verifyNever(() => remote.updateCourtType(1, input));
    });

    test('savePlan không có id thì tạo, có id thì sửa', () async {
      const input = SubscriptionPlanInput(name: 'Cơ bản', maxBranches: 1, maxCourts: 5);
      when(() => remote.createPlan(input))
          .thenAnswer((_) async => SubscriptionPlanModel.fromJson(planJson()));
      when(() => remote.updatePlan(4, input))
          .thenAnswer((_) async => SubscriptionPlanModel.fromJson(planJson(id: 4)));

      expect((await repository.savePlan(input)).id, 1);
      expect((await repository.savePlan(input, id: 4)).id, 4);
    });

    test('plans đổi model sang entity', () async {
      when(() => remote.plans(1, 20)).thenAnswer(
        (_) async => pageOf([SubscriptionPlanModel.fromJson(planJson())], page: 1, totalPages: 2),
      );

      final page = await repository.plans(page: 1, size: 20);

      expect(page.items.single.name, 'Cơ bản');
      expect(page.page, 1);
    });

    test('tên trùng: 409 giữ lý do của BE', () async {
      when(() => remote.createCourtType(any())).thenThrow(
        dioError(409, body: {'detail': 'Court type name already exists'}),
      );

      await expectLater(
        repository.saveCourtType(const CourtTypeInput(name: 'Cầu lông')),
        throwsA(const ServerFailure('Court type name already exists', statusCode: 409)),
      );
    });

    test('lỗi validation theo field được giữ lại', () async {
      when(() => remote.createPlan(any())).thenThrow(
        dioError(400, body: {
          'detail': 'Invalid request fields',
          'errors': [
            {'field': 'maxBranches', 'message': 'maxBranches must be at least 1'},
          ],
        }),
      );

      await expectLater(
        repository.savePlan(const SubscriptionPlanInput(name: 'x', maxBranches: 0, maxCourts: 1)),
        throwsA(
          const ServerFailure(
            'Invalid request fields',
            statusCode: 400,
            fieldErrors: {'maxBranches': 'maxBranches must be at least 1'},
          ),
        ),
      );
    });

    test('không phải super admin: 403 thành ServerFailure có mã 403', () async {
      when(() => remote.deleteCourtType(any())).thenThrow(
        dioError(403, body: {'detail': 'You are not allowed to perform this action'}),
      );

      await expectLater(
        repository.deleteCourtType(1),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('xóa mục không còn tồn tại: 404', () async {
      when(() => remote.deletePlan(any()))
          .thenThrow(dioError(404, body: {'detail': 'Subscription plan not found'}));

      await expectLater(
        repository.deletePlan(9),
        throwsA(const ServerFailure('Subscription plan not found', statusCode: 404)),
      );
    });

    test('mất mạng thành NetworkFailure', () async {
      when(() => remote.courtTypes(any(), any()))
          .thenThrow(dioError(null, type: DioExceptionType.connectionError));

      await expectLater(
        repository.courtTypes(page: 0, size: 20),
        throwsA(const NetworkFailure()),
      );
    });

    test('body sai hợp đồng thành UnknownFailure thay vì lỗi kiểu dữ liệu', () async {
      when(() => remote.courtTypes(any(), any())).thenAnswer(
        (_) async => pageOf([CourtTypeModel.fromJson(const {'name': 'thiếu id'})]),
      );

      await expectLater(
        repository.courtTypes(page: 0, size: 20),
        throwsA(const UnknownFailure()),
      );
    });

    test('xóa thành công không ném lỗi', () async {
      when(() => remote.deleteCourtType(1)).thenAnswer((_) async {});
      when(() => remote.deletePlan(1)).thenAnswer((_) async {});

      await repository.deleteCourtType(1);
      await repository.deletePlan(1);

      verify(() => remote.deleteCourtType(1)).called(1);
      verify(() => remote.deletePlan(1)).called(1);
    });
  });
}
