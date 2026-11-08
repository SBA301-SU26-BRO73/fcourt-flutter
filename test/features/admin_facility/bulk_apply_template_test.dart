import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_facility/data/datasources/facility_remote_data_source.dart';
import 'package:fcourt/features/admin_facility/data/repositories/slot_template_repository_impl.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/slot_template.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/apply_slot_template.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/court_usecases.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/bulk_apply_template_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/court_list_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/court_list_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/widgets/bulk_apply_template_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_adapter.dart';
import 'fixtures.dart';
import 'mocks.dart';

const _request = BulkSlotTemplateRequest(
  courtIds: [5, 6],
  startTime: ClockTime(6, 0),
  endTime: ClockTime(7, 0),
  daysOfWeek: [1, 2],
);

const _previewJson = {
  'courts': [
    {
      'courtId': 5,
      'courtName': 'Sân 5',
      'branchId': 1,
      'daysOfWeek': [1, 2],
      'slots': [
        {'startTime': '06:00', 'endTime': '06:30', 'price': 60000.0},
        {'startTime': '06:30', 'endTime': '07:00', 'price': 60000.0},
      ],
      'totalSlots': 4,
      'conflict': null,
    },
    {
      'courtId': 6,
      'courtName': 'Sân 6',
      'branchId': 2,
      'daysOfWeek': <int>[],
      'slots': <Object>[],
      'totalSlots': 0,
      'conflict': 'Slots must be within branch hours 08:00-20:00',
    },
  ],
  'totalSlots': 4,
  'hasConflicts': true,
};

({FakeAdapter adapter, SlotTemplateRepositoryImpl repo}) _repo(
  FakeHandler handler,
) {
  final adapter = FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://facility'))
    ..httpClientAdapter = adapter;
  return (
    adapter: adapter,
    repo: SlotTemplateRepositoryImpl(FacilityRemoteDataSource(dio)),
  );
}

void main() {
  setUpAll(() {
    registerFacilityFallbacks();
    registerFallbackValue(_request);
  });

  group('SlotTemplateRepositoryImpl bulk', () {
    test('preview gửi {courtIds, template} và đọc xung đột từng sân', () async {
      final r = _repo((_) => jsonResponse(200, _previewJson));

      final preview = await r.repo.previewBulk(_request);

      final sent = r.adapter.requests.single;
      expect(
        '${sent.method} ${sent.path}',
        'POST /api/admin/courts/bulk-apply-template/preview',
      );
      expect(sent.data, {
        'courtIds': [5, 6],
        'template': {
          'startTime': '06:00',
          'endTime': '07:00',
          'durationMinutes': 30,
          'daysOfWeek': [1, 2],
        },
      });
      expect(preview.hasConflicts, isTrue);
      expect(preview.totalSlots, 4);
      expect(preview.courts.first.slots.first.price, 60000);
      expect(preview.courts.first.conflict, isNull);
      expect(
        preview.courts.last.conflict,
        'Slots must be within branch hours 08:00-20:00',
      );
    });

    test('apply gửi price khi có và đọc tổng slot', () async {
      final r = _repo(
        (_) => jsonResponse(200, {
          'courts': [
            {
              'courtId': 5,
              'courtName': 'Sân 5',
              'daysOfWeek': [1, 2],
              'slotsPerDay': 2,
              'totalSlots': 4,
            },
            {
              'courtId': 6,
              'courtName': 'Sân 6',
              'daysOfWeek': [1, 2],
              'slotsPerDay': 2,
              'totalSlots': 4,
            },
          ],
          'totalSlots': 8,
        }),
      );

      final applied = await r.repo.applyBulk(
        const BulkSlotTemplateRequest(
          courtIds: [5, 6],
          startTime: ClockTime(6, 0),
          endTime: ClockTime(7, 0),
          price: 50000,
          daysOfWeek: [1, 2],
        ),
      );

      final sent = r.adapter.requests.single;
      expect(sent.path, '/api/admin/courts/bulk-apply-template');
      expect((sent.data as Map)['template'], containsPair('price', 50000));
      expect(applied, const BulkApplied(courtCount: 2, totalSlots: 8));
    });

    test('409 conflicts và 404 → tiếng Việt', () async {
      var status = 409;
      final r = _repo(
        (_) => status == 409
            ? jsonResponse(409, {
                'status': 409,
                'detail': 'Template cannot be applied to 2 court(s); nothing was changed',
                'conflicts': [
                  {'courtId': 6, 'message': 'x'},
                ],
              })
            : jsonResponse(404, {'status': 404, 'detail': 'Court not found'}),
      );

      await expectLater(
        r.repo.applyBulk(_request),
        throwsA(
          isA<ServerFailure>()
              .having((f) => f.statusCode, 'status', 409)
              .having(
                (f) => f.message,
                'message',
                contains('không có thay đổi nào được lưu'),
              ),
        ),
      );
      status = 404;
      await expectLater(
        r.repo.applyBulk(_request),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.message,
            'message',
            contains('không thuộc quyền'),
          ),
        ),
      );
    });

    test('response thiếu courts → UnknownFailure', () async {
      final r = _repo((_) => jsonResponse(200, {'totalSlots': 1}));

      await expectLater(
        r.repo.previewBulk(_request),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('BulkApplyTemplateBloc', () {
    late MockSlotTemplateRepository templates;
    final courts = [sampleCourt(), sampleCourt(id: 6), sampleCourt(id: 7)];

    BulkApplyTemplateBloc build() => BulkApplyTemplateBloc(
      courts: courts,
      start: const ClockTime(6, 0),
      end: const ClockTime(22, 0),
      branchOpen: const ClockTime(6, 0),
      branchClose: const ClockTime(22, 0),
      previewBulk: PreviewBulkSlotTemplate(templates),
      applyBulk: ApplyBulkSlotTemplate(templates),
    );

    setUp(() => templates = MockSlotTemplateRepository());

    test(
      'chưa chọn sân thì không có request; chọn tất cả rồi bỏ hết',
      () async {
        final bloc = build();
        expect(bloc.state.request, isNull);

        bloc.add(const BulkSelectAllToggled());
        var state = await bloc.stream.first;
        expect(state.allSelected, isTrue);
        expect(state.request!.courtIds, [5, 6, 7]);

        bloc.add(const BulkSelectAllToggled());
        state = await bloc.stream.first;
        expect(state.selectedIds, isEmpty);
        expect(state.request, isNull);
        await bloc.close();
      },
    );

    test('sân thiếu giá giờ cần nhập giá mỗi slot mới có request', () async {
      final bloc = BulkApplyTemplateBloc(
        courts: [sampleCourt(price: null)],
        start: const ClockTime(6, 0),
        end: const ClockTime(7, 0),
        previewBulk: PreviewBulkSlotTemplate(templates),
        applyBulk: ApplyBulkSlotTemplate(templates),
      )..add(const BulkSelectAllToggled());
      var state = await bloc.stream.first;
      expect(state.courtsMissingPrice, hasLength(1));
      expect(state.request, isNull);

      bloc.add(const BulkPriceChanged(50000));
      state = await bloc.stream.first;
      expect(state.request!.price, 50000);
      await bloc.close();
    });

    test(
      'giờ ngoài giờ chi nhánh hoặc không chọn ngày → không có request',
      () async {
        final bloc = build()..add(const BulkSelectAllToggled());
        await bloc.stream.first;

        bloc.add(const BulkRangeChanged(start: ClockTime(5, 0)));
        expect((await bloc.stream.first).request, isNull);
        bloc.add(const BulkRangeChanged(start: ClockTime(6, 0)));
        expect((await bloc.stream.first).request, isNotNull);
        for (var day = 0; day < 7; day++) {
          bloc.add(BulkDayToggled(day));
        }
        await bloc.stream.firstWhere((s) => s.daysOfWeek.isEmpty);
        expect(bloc.state.request, isNull);
        await bloc.close();
      },
    );

    test('xem trước có xung đột thì không áp dụng được', () async {
      when(() => templates.previewBulk(any())).thenAnswer(
        (_) async =>
            const BulkPreview(courts: [], totalSlots: 0, hasConflicts: true),
      );
      final bloc = build()..add(const BulkSelectAllToggled());
      await bloc.stream.first;
      bloc.add(const BulkPreviewRequested());
      await bloc.stream.firstWhere((s) => s.status == BulkApplyStatus.preview);

      bloc.add(const BulkApplyRequested());
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => templates.applyBulk(any()));
      expect(bloc.state.status, BulkApplyStatus.preview);
      await bloc.close();
    });

    test('chưa xem trước thì không gọi apply', () async {
      final bloc = build()..add(const BulkSelectAllToggled());
      await bloc.stream.first;

      bloc.add(const BulkApplyRequested());
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => templates.applyBulk(any()));
      await bloc.close();
    });

    test('xem trước → xác nhận → done với số sân/slot', () async {
      when(() => templates.previewBulk(any())).thenAnswer(
        (_) async =>
            const BulkPreview(courts: [], totalSlots: 96, hasConflicts: false),
      );
      when(() => templates.applyBulk(any())).thenAnswer(
        (_) async => const BulkApplied(courtCount: 3, totalSlots: 96),
      );
      final bloc = build()..add(const BulkSelectAllToggled());
      await bloc.stream.first;

      bloc.add(const BulkPreviewRequested());
      await bloc.stream.firstWhere((s) => s.status == BulkApplyStatus.preview);
      bloc.add(const BulkApplyRequested());
      final done = await bloc.stream.firstWhere(
        (s) => s.status == BulkApplyStatus.done,
      );

      expect(done.applied, const BulkApplied(courtCount: 3, totalSlots: 96));
      verify(() => templates.applyBulk(any())).called(1);
      await bloc.close();
    });

    test('apply lỗi (409) → về bước chỉnh sửa kèm thông báo', () async {
      when(() => templates.previewBulk(any())).thenAnswer(
        (_) async =>
            const BulkPreview(courts: [], totalSlots: 1, hasConflicts: false),
      );
      when(() => templates.applyBulk(any())).thenThrow(
        const ServerFailure('Có sân không áp dụng được', statusCode: 409),
      );
      final bloc = build()..add(const BulkSelectAllToggled());
      await bloc.stream.first;
      bloc.add(const BulkPreviewRequested());
      await bloc.stream.firstWhere((s) => s.status == BulkApplyStatus.preview);

      bloc.add(const BulkApplyRequested());
      final state = await bloc.stream.firstWhere((s) => s.error != null);

      expect(state.status, BulkApplyStatus.editing);
      expect(state.error, 'Có sân không áp dụng được');
      await bloc.close();
    });
  });

  group('Hộp thoại bulk apply trong CourtListScreen', () {
    late MockBranchRepository branches;
    late MockCourtRepository courts;
    late MockCourtTypeRepository types;
    late MockSlotTemplateRepository templates;

    Widget screen() => BlocProvider(
      create: (_) => CourtListBloc(
        getBranches: GetBranches(branches),
        getCourts: GetCourts(courts),
        getCourtTypes: GetCourtTypes(types),
        toggleMaintenance: ToggleCourtMaintenance(courts),
      )..add(const CourtListStarted(1)),
      child: Builder(
        builder: (context) => CourtListScreen(
          onCreateCourt: (_) async => null,
          onEditCourt: (_) async => null,
          onOpenSlotTemplate: (_) {},
          onBulkApply: (branch, list) => showBulkApplyTemplateDialog(
            context,
            createBloc: () => BulkApplyTemplateBloc(
              courts: list,
              start: branch.openTime,
              end: branch.closeTime,
              branchOpen: branch.openTime,
              branchClose: branch.closeTime,
              previewBulk: PreviewBulkSlotTemplate(templates),
              applyBulk: ApplyBulkSlotTemplate(templates),
            ),
          ),
        ),
      ),
    );

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: screen()));
      await tester.pumpAndSettle();
    }

    setUp(() {
      branches = MockBranchRepository();
      courts = MockCourtRepository();
      types = MockCourtTypeRepository();
      templates = MockSlotTemplateRepository();
      when(() => types.getCourtTypes())
          .thenAnswer((_) async => sampleCourtTypes);
      when(() => branches.getBranches())
          .thenAnswer((_) async => [sampleBranch()]);
      when(() => courts.getCourts(1)).thenAnswer(
        (_) async => [sampleCourt(), sampleCourt(id: 6), sampleCourt(id: 7)],
      );
    });

    testWidgets('chọn tất cả → xem trước → xác nhận → SnackBar và tải lại', (
      tester,
    ) async {
      when(() => templates.previewBulk(any())).thenAnswer(
        (_) async => BulkPreview(
          courts: [
            for (final id in [5, 6, 7])
              BulkPreviewCourt(
                courtId: id,
                courtName: 'Sân $id',
                daysOfWeek: const [0, 1, 2, 3, 4, 5, 6],
                slots: const [
                  GeneratedSlot(
                    startTime: ClockTime(6, 0),
                    endTime: ClockTime(6, 30),
                    price: 60000,
                  ),
                ],
                totalSlots: 7,
              ),
          ],
          totalSlots: 21,
          hasConflicts: false,
        ),
      );
      when(() => templates.applyBulk(any())).thenAnswer(
        (_) async => const BulkApplied(courtCount: 3, totalSlots: 21),
      );
      await pump(tester);

      await tester.tap(find.byKey(const Key('court-bulk-apply')));
      await tester.pumpAndSettle();
      final previewButton = find.byKey(const Key('bulk-preview'));
      expect(tester.widget<FilledButton>(previewButton).onPressed, isNull);

      await tester.tap(find.byKey(const Key('bulk-select-all')));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 3 sân'), findsOneWidget);
      await tester.tap(previewButton);
      await tester.pumpAndSettle();

      expect(find.text('Xem trước: 3 sân · 21 slot'), findsOneWidget);
      expect(find.text('1 slot/ngày × 7 ngày = 7 slot'), findsNWidgets(3));
      await tester.tap(find.byKey(const Key('bulk-confirm')));
      await tester.pumpAndSettle();

      expect(find.byType(BulkApplyTemplateDialog), findsNothing);
      expect(find.text('Đã áp dụng mẫu cho 3 sân (21 slot)'), findsOneWidget);
      // Danh sách được tải lại sau khi áp dụng.
      verify(() => courts.getCourts(1)).called(2);
    });

    testWidgets('xem trước có xung đột: báo rõ sân và khóa nút xác nhận', (
      tester,
    ) async {
      when(() => templates.previewBulk(any())).thenAnswer(
        (_) async => const BulkPreview(
          courts: [
            BulkPreviewCourt(
              courtId: 5,
              courtName: 'Sân 5',
              daysOfWeek: [],
              slots: [],
              totalSlots: 0,
              conflict: 'Slots must be within branch hours 06:00-22:00',
            ),
          ],
          totalSlots: 0,
          hasConflicts: true,
        ),
      );
      await pump(tester);
      await tester.tap(find.byKey(const Key('court-bulk-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulk-court-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulk-preview')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bulk-conflict-banner')), findsOneWidget);
      expect(
        find.text('Ngoài giờ mở cửa của chi nhánh (06:00-22:00)'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('bulk-confirm')))
            .onPressed,
        isNull,
      );
      verifyNever(() => templates.applyBulk(any()));

      await tester.tap(find.byKey(const Key('bulk-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bulk-select-all')), findsOneWidget);
    });

    testWidgets('lỗi xem trước hiện trong hộp thoại, đóng thì không đổi gì', (
      tester,
    ) async {
      when(
        () => templates.previewBulk(any()),
      ).thenThrow(const ServerFailure('Không tìm thấy sân', statusCode: 404));
      await pump(tester);
      await tester.tap(find.byKey(const Key('court-bulk-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulk-select-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulk-preview')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bulk-error')), findsOneWidget);
      await tester.tap(find.byKey(const Key('bulk-close')));
      await tester.pumpAndSettle();

      expect(find.byType(BulkApplyTemplateDialog), findsNothing);
      verify(() => courts.getCourts(1)).called(1);
      verifyNever(() => templates.applyBulk(any()));
    });
  });
}
