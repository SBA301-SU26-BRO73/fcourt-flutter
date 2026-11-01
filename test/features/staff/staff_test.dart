import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/core/network/command_key.dart';
import 'package:fcourt/features/staff/data/http_staff_repository.dart';
import 'package:fcourt/features/staff/domain/staff.dart';
import 'package:fcourt/features/staff/domain/staff_validation.dart';
import 'package:fcourt/features/staff/presentation/staff_cubit.dart';
import 'package:fcourt/features/staff/presentation/staff_page.dart';
import 'package:fcourt/features/staff/presentation/staff_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

const member = StaffMember(
  id: 4,
  branchId: 7,
  name: 'Khoa',
  email: 'khoa@example.com',
  phone: '0912345678',
  active: true,
  shifts: [WorkShift(1, '09:00', '17:00')],
);
const draft = StaffDraft(
  branchId: 7,
  name: 'Khoa',
  email: 'KHOA@example.com',
  phone: '0912345678',
  password: 'password12345',
);

class FakeStaff implements StaffRepository {
  List<StaffBranch> branchRows = [const StaffBranch(7, 'Cơ sở 1')];
  List<StaffMember> rows = [member];
  Failure? error;
  final keys = <String>[];
  Future<List<StaffMember>> Function(int)? loader;
  @override
  Future<List<StaffBranch>> branches() async => branchRows;
  @override
  Future<List<StaffMember>> list(int branchId, {int offset = 0}) async {
    if (loader != null) return loader!(branchId);
    if (error != null) throw error!;
    return rows;
  }

  @override
  Future<void> save(StaffDraft draft, String key, {int? id}) async {
    keys.add(key);
    if (error != null) throw error!;
  }

  @override
  Future<void> setActive(StaffMember member, bool active, String key) async {
    keys.add(key);
  }
}

void main() {
  testWidgets('disable confirms and refreshes the list', (tester) async {
    final fake = FakeStaff();
    await tester.pumpWidget(MaterialApp(home: StaffPage(repository: fake)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khóa tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Khóa nhân viên?'), findsOneWidget);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(fake.keys, hasLength(1));
    expect(find.text('Đã cập nhật trạng thái'), findsOneWidget);
  });

  testWidgets('empty list and load failure provide recovery', (tester) async {
    final fake = FakeStaff()..error = const NetworkFailure();
    await tester.pumpWidget(MaterialApp(home: StaffPage(repository: fake)));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    fake.error = null;
    fake.rows = [];
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có nhân viên.'), findsOneWidget);
    await tester.tap(find.text('Thêm nhân viên'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu nhân viên'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Khoa');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.vn');
    await tester.enterText(find.byType(TextFormField).at(2), '0912345678');
    await tester.enterText(find.byType(TextFormField).at(3), 'password12345');
    await tester.ensureVisible(find.text('Lưu nhân viên'));
    await tester.tap(find.text('Lưu nhân viên'));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu thông tin nhân viên'), findsOneWidget);
  });

  testWidgets('no owned branch has helpful empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: StaffPage(repository: FakeStaff()..branchRows = [])),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có chi nhánh'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  test('validation matches bounds including utf8 passwords', () {
    expect(validateStaffName(' '), isNotNull);
    expect(validateStaffName('Khoa'), isNull);
    expect(validateStaffName('x' * 151), isNotNull);
    expect(validateStaffEmail('wrong'), isNotNull);
    expect(validateStaffEmail(' a@b.vn '), isNull);
    expect(validateStaffPhone('09123'), isNotNull);
    expect(validateStaffPhone('+84912345678'), isNull);
    expect(validateStaffPassword('short123'), isNotNull);
    expect(validateStaffPassword('abcdefghijkl'), isNotNull);
    expect(validateStaffPassword('password12345'), isNull);
    expect(validateStaffPassword('${'ấ' * 25}abc123'), isNotNull);
  });

  test('command keys are unique rfc4122 v4 uuids', () {
    final keys = List.generate(100, (_) => newCommandKey());
    expect(keys.toSet(), hasLength(100));
    expect(
      keys,
      everyElement(
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      ),
    );
  });

  test('staff http uses exact create/update and lifecycle contracts', () async {
    final adapter = FakeAdapter(
      (r) => jsonResponse(
        200,
        r.path == '/api/admin/branches'
            ? [
                {'id': 7, 'name': 'Cơ sở 1', 'status': 'ACTIVE'},
                {'id': 8, 'name': 'Closed', 'status': 'INACTIVE'},
              ]
            : r.method == 'GET'
            ? [
                {
                  'id': 4,
                  'branchId': 7,
                  'fullName': null,
                  'email': null,
                  'phone': null,
                  'active': false,
                  'shifts': [],
                },
              ]
            : {},
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    final repo = HttpStaffRepository(dio, dio);
    expect(await repo.branches(), hasLength(1));
    expect((await repo.list(7, offset: 50)).single.name, 'Chưa có tên');
    expect(adapter.requests.last.queryParameters['offset'], 50);
    await repo.save(draft, 'key');
    expect(adapter.requests.last.data, {
      'branchId': 7,
      'email': 'khoa@example.com',
      'password': 'password12345',
      'fullName': 'Khoa',
      'phone': '0912345678',
      'shifts': [],
    });
    expect(adapter.requests.last.headers['Idempotency-Key'], 'key');
    await repo.save(draft, 'key2', id: 4);
    expect(adapter.requests.last.method, 'PUT');
    expect(
      (adapter.requests.last.data as Map).containsKey('password'),
      isFalse,
    );
    expect((adapter.requests.last.data as Map).containsKey('email'), isFalse);
    await repo.setActive(member, false, 'key3');
    expect(adapter.requests.last.method, 'DELETE');
    await repo.setActive(member, true, 'key4');
    expect(adapter.requests.last.path, '/api/admin/staff/4/reactivate');
  });

  test('http errors become domain failures', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FakeAdapter(
        (_) => jsonResponse(409, {'message': 'duplicate'}),
      );
    await expectLater(
      HttpStaffRepository(dio, dio).save(draft, 'key'),
      throwsA(const ServerFailure('duplicate', statusCode: 409)),
    );
  });

  test(
    'cubit loads branches, handles failures, ignores stale branch response',
    () async {
      final fake = FakeStaff();
      final cubit = StaffCubit(fake);
      await cubit.initialize();
      expect(cubit.state.branchId, 7);
      expect(cubit.state.members, [member]);
      fake.error = const NetworkFailure();
      await cubit.load(7);
      expect(cubit.state.error, isNotNull);
      final old = Completer<List<StaffMember>>();
      fake.loader = (id) => id == 7 ? old.future : Future.value([]);
      final first = cubit.load(7);
      await cubit.load(8);
      old.complete([member]);
      await first;
      expect(cubit.state.branchId, 8);
      expect(cubit.state.members, isEmpty);
      await cubit.close();
    },
  );

  testWidgets('management displays branch, contact and edit sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: StaffPage(repository: FakeStaff())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Khoa'), findsOneWidget);
    expect(find.textContaining('khoa@example.com'), findsOneWidget);
    await tester.tap(find.text('Khoa'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa nhân viên'), findsOneWidget);
    final email = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(email.enabled, isFalse);
  });

  testWidgets('ambiguous create locks fields and keeps retry identity', (
    tester,
  ) async {
    final fake = FakeStaff()..error = const NetworkFailure();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffSheet(
            repository: fake,
            branches: fake.branchRows,
            branchId: 7,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Khoa');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.vn');
    await tester.enterText(find.byType(TextFormField).at(2), '0912345678');
    await tester.enterText(find.byType(TextFormField).at(3), 'password12345');
    await tester.ensureVisible(find.text('Lưu nhân viên'));
    await tester.tap(find.text('Lưu nhân viên'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
      isFalse,
    );
    await tester.ensureVisible(find.text('Thử lại lệnh đã gửi'));
    await tester.tap(find.text('Thử lại lệnh đã gửi'));
    await tester.pumpAndSettle();
    expect(fake.keys, hasLength(2));
    expect(fake.keys[0], fake.keys[1]);
  });

  for (final width in [320.0, 1000.0]) {
    testWidgets('layout supports width $width and large text', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: StaffPage(repository: FakeStaff()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
