import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/court.dart';
import 'package:fcourt/features/admin_facility/domain/entities/slot_matrix.dart';
import 'package:fcourt/features/admin_facility/domain/entities/slot_template.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/apply_slot_template.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/court_usecases.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/branch_form_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/branch_list_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/court_form_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/court_list_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/slot_template_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures.dart';
import '../mocks.dart';

void main() {
  late MockBranchRepository branches;
  late MockCourtRepository courts;
  late MockCourtTypeRepository types;
  late MockSlotTemplateRepository templates;

  setUpAll(registerFacilityFallbacks);

  setUp(() {
    branches = MockBranchRepository();
    courts = MockCourtRepository();
    types = MockCourtTypeRepository();
    templates = MockSlotTemplateRepository();
    when(() => types.getCourtTypes()).thenAnswer((_) async => sampleCourtTypes);
  });

  group('BranchListBloc', () {
    blocTest<BranchListBloc, BranchListState>(
      'loading rồi success với danh sách chi nhánh',
      build: () {
        when(() => branches.getBranches())
            .thenAnswer((_) async => [sampleBranch()]);
        return BranchListBloc(GetBranches(branches));
      },
      act: (bloc) => bloc.add(const BranchListRequested()),
      expect: () => [
        const BranchListState(status: BranchListStatus.loading),
        BranchListState(
          status: BranchListStatus.success,
          branches: [sampleBranch()],
        ),
      ],
    );

    blocTest<BranchListBloc, BranchListState>(
      'lỗi mạng → failure kèm thông báo',
      build: () {
        when(() => branches.getBranches()).thenThrow(const NetworkFailure());
        return BranchListBloc(GetBranches(branches));
      },
      act: (bloc) => bloc.add(const BranchListRequested()),
      expect: () => [
        const BranchListState(status: BranchListStatus.loading),
        const BranchListState(
          status: BranchListStatus.failure,
          message: 'Không kết nối được máy chủ',
        ),
      ],
    );
  });

  group('BranchFormBloc', () {
    BranchFormBloc build({int? id}) => BranchFormBloc(
      getBranch: GetBranch(branches),
      saveBranch: SaveBranch(branches),
      branchId: id,
    );

    blocTest<BranchFormBloc, BranchFormState>(
      'tạo mới gọi POST và trả về chi nhánh đã lưu',
      build: () {
        when(() => branches.createBranch(any()))
            .thenAnswer((_) async => sampleBranch(id: 9));
        return build();
      },
      act: (bloc) => bloc.add(BranchFormSubmitted(draftWith())),
      expect: () => [
        const BranchFormState(status: BranchFormStatus.submitting),
        BranchFormState(
          status: BranchFormStatus.success,
          saved: sampleBranch(id: 9),
        ),
      ],
      verify: (_) => verify(() => branches.createBranch(draftWith())).called(1),
    );

    blocTest<BranchFormBloc, BranchFormState>(
      'giờ đóng cửa trước giờ mở cửa bị chặn, không gọi API',
      build: build,
      act: (bloc) => bloc.add(
        BranchFormSubmitted(
          draftWith(open: const ClockTime(22, 0), close: const ClockTime(6, 0)),
        ),
      ),
      expect: () => [
        const BranchFormState(
          status: BranchFormStatus.failure,
          message: 'Giờ đóng cửa phải sau giờ mở cửa',
        ),
      ],
      verify: (_) => verifyNever(() => branches.createBranch(any())),
    );

    blocTest<BranchFormBloc, BranchFormState>(
      'sửa: tải chi nhánh rồi PUT',
      build: () {
        when(() => branches.getBranch(1))
            .thenAnswer((_) async => sampleBranch());
        when(() => branches.updateBranch(1, any()))
            .thenAnswer((_) async => sampleBranch(name: 'Mới'));
        return build(id: 1);
      },
      act: (bloc) async {
        bloc.add(const BranchFormStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(BranchFormSubmitted(draftWith()));
      },
      skip: 2,
      expect: () => [
        BranchFormState(
          status: BranchFormStatus.submitting,
          initial: sampleBranch(),
        ),
        BranchFormState(
          status: BranchFormStatus.success,
          initial: sampleBranch(),
          saved: sampleBranch(name: 'Mới'),
        ),
      ],
    );

    blocTest<BranchFormBloc, BranchFormState>(
      'lỗi server hiển thị detail',
      build: () {
        when(() => branches.createBranch(any())).thenThrow(
          const ServerFailure('Đã đạt giới hạn gói', statusCode: 403),
        );
        return build();
      },
      act: (bloc) => bloc.add(BranchFormSubmitted(draftWith())),
      skip: 1,
      expect: () => [
        const BranchFormState(
          status: BranchFormStatus.failure,
          message: 'Đã đạt giới hạn gói',
        ),
      ],
    );
  });

  group('CourtListBloc', () {
    CourtListBloc build() => CourtListBloc(
      getBranches: GetBranches(branches),
      getCourts: GetCourts(courts),
      getCourtTypes: GetCourtTypes(types),
      toggleMaintenance: ToggleCourtMaintenance(courts),
    );

    test('tải chi nhánh, loại sân và sân của chi nhánh', () async {
      when(() => branches.getBranches())
          .thenAnswer((_) async => [sampleBranch(), sampleBranch(id: 2)]);
      when(() => courts.getCourts(1)).thenAnswer((_) async => [sampleCourt()]);
      final bloc = build()..add(const CourtListStarted(1));

      final state = await bloc.stream.firstWhere(
        (s) => s.status == CourtListStatus.success,
      );

      expect(state.selectedBranchId, 1);
      expect(state.branches, hasLength(2));
      expect(state.courts, [sampleCourt()]);
      expect(state.courtTypeName(6), 'Cầu lông');
      await bloc.close();
    });

    test('đổi chi nhánh: phản hồi cũ về muộn không ghi đè', () async {
      final slow = Completer<List<Court>>();
      when(() => branches.getBranches()).thenAnswer((_) async => []);
      when(() => courts.getCourts(1)).thenAnswer((_) => slow.future);
      when(() => courts.getCourts(2))
          .thenAnswer((_) async => [sampleCourt(id: 20, branchId: 2)]);
      final bloc = build()..add(const CourtListStarted(1));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const CourtBranchSelected(2));
      await bloc.stream.firstWhere((s) => s.status == CourtListStatus.success);
      slow.complete([sampleCourt()]);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.selectedBranchId, 2);
      expect(bloc.state.courts.single.id, 20);
      await bloc.close();
    });

    test('bật bảo trì gọi PATCH, cập nhật thẻ và báo SnackBar', () async {
      when(() => branches.getBranches()).thenAnswer((_) async => []);
      when(() => courts.getCourts(1)).thenAnswer((_) async => [sampleCourt()]);
      when(
        () => courts.changeStatus(5, CourtStatus.maintenance),
      ).thenAnswer((_) async => sampleCourt(status: CourtStatus.maintenance));
      final bloc = build()..add(const CourtListStarted(1));
      await bloc.stream.firstWhere((s) => s.status == CourtListStatus.success);

      bloc.add(const CourtMaintenanceToggled(5, maintenance: true));
      final state = await bloc.stream.firstWhere((s) => s.notice != null);

      expect(state.courts.single.status, CourtStatus.maintenance);
      expect(state.updatingIds, isEmpty);
      expect(state.notice!.message, 'Đã chuyển "Sân 5" sang bảo trì');
      expect(state.notice!.isError, isFalse);
      await bloc.close();
    });

    test('đổi trạng thái lỗi giữ nguyên thẻ và báo lỗi', () async {
      when(() => branches.getBranches()).thenAnswer((_) async => []);
      when(() => courts.getCourts(1)).thenAnswer((_) async => [sampleCourt()]);
      when(() => courts.changeStatus(5, any()))
          .thenThrow(const ServerFailure('Không có quyền', statusCode: 403));
      final bloc = build()..add(const CourtListStarted(1));
      await bloc.stream.firstWhere((s) => s.status == CourtListStatus.success);

      bloc.add(const CourtMaintenanceToggled(5, maintenance: true));
      final state = await bloc.stream.firstWhere((s) => s.notice != null);

      expect(state.courts.single.status, CourtStatus.active);
      expect(state.notice!.isError, isTrue);
      await bloc.close();
    });

    test('CourtSaved thêm sân mới vào lưới ngay', () async {
      when(() => branches.getBranches()).thenAnswer((_) async => []);
      when(() => courts.getCourts(1)).thenAnswer((_) async => [sampleCourt()]);
      final bloc = build()..add(const CourtListStarted(1));
      await bloc.stream.firstWhere((s) => s.status == CourtListStatus.success);

      bloc.add(CourtSaved(sampleCourt(id: 6)));
      final state = await bloc.stream.firstWhere((s) => s.notice != null);

      expect(state.courts.map((c) => c.id), [5, 6]);
      expect(state.notice!.message, 'Đã thêm sân "Sân 6"');
      await bloc.close();
    });
  });

  group('CourtFormBloc', () {
    blocTest<CourtFormBloc, CourtFormState>(
      'tạo sân trong chi nhánh được chọn',
      build: () {
        when(() => courts.createCourt(1, any()))
            .thenAnswer((_) async => sampleCourt(id: 8));
        return CourtFormBloc(
          getCourt: GetCourt(courts),
          saveCourt: SaveCourt(courts),
          getCourtTypes: GetCourtTypes(types),
          branchId: 1,
        );
      },
      act: (bloc) async {
        bloc.add(const CourtFormStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(CourtFormSubmitted(sampleCourt().toDraft()));
      },
      verify: (bloc) {
        expect(bloc.state.status, CourtFormStatus.success);
        expect(bloc.state.saved, sampleCourt(id: 8));
        expect(bloc.state.courtTypes, sampleCourtTypes);
      },
    );

    blocTest<CourtFormBloc, CourtFormState>(
      'giá <= 0 bị chặn',
      build: () => CourtFormBloc(
        getCourt: GetCourt(courts),
        saveCourt: SaveCourt(courts),
        getCourtTypes: GetCourtTypes(types),
        branchId: 1,
      ),
      act: (bloc) => bloc.add(
        const CourtFormSubmitted(
          CourtDraft(name: 'A', courtTypeId: 6, defaultPricePerHour: 0),
        ),
      ),
      expect: () => [
        const CourtFormState(
          status: CourtFormStatus.failure,
          message: 'Giá mỗi giờ phải lớn hơn 0',
        ),
      ],
      verify: (_) => verifyNever(() => courts.createCourt(any(), any())),
    );
  });

  group('SlotTemplateBloc', () {
    SlotTemplateBloc build() => SlotTemplateBloc(
      courtId: 5,
      getCourt: GetCourt(courts),
      getBranch: GetBranch(branches),
      applyTemplate: ApplySlotTemplate(templates),
    );

    setUp(() {
      when(() => courts.getCourt(5)).thenAnswer((_) async => sampleCourt());
      when(() => branches.getBranch(1)).thenAnswer((_) async => sampleBranch());
    });

    test('mặc định theo giờ chi nhánh, giá = nửa giá giờ, 32 slot', () async {
      final bloc = build()..add(const SlotTemplateStarted());
      final state = await bloc.stream.firstWhere(
        (s) => s.status == SlotTemplateStatus.ready,
      );

      expect(state.start, const ClockTime(6, 0));
      expect(state.end, const ClockTime(22, 0));
      expect(state.price, 60000);
      expect(state.slots, hasLength(32));
      expect(state.request, isNotNull);
      await bloc.close();
    });

    test(
      'giờ kết thúc sớm hơn giờ bắt đầu → cảnh báo, không áp dụng',
      () async {
        final bloc = build()..add(const SlotTemplateStarted());
        await bloc.stream.firstWhere(
          (s) => s.status == SlotTemplateStatus.ready,
        );

        bloc.add(const SlotTemplateRangeChanged(end: ClockTime(5, 0)));
        final state = await bloc.stream.first;

        expect(state.rangeIssue, SlotRangeIssue.endNotAfterStart);
        expect(state.slots, isEmpty);
        expect(state.request, isNull);
        await bloc.close();
      },
    );

    test('áp dụng gửi request đã chọn và báo số slot', () async {
      when(() => templates.applyTemplate(5, any())).thenAnswer(
        (_) async => const AppliedTemplate(
          courtId: 5,
          daysOfWeek: [1, 2, 3, 4, 5],
          totalSlots: 40,
        ),
      );
      final bloc = build()..add(const SlotTemplateStarted());
      await bloc.stream.firstWhere((s) => s.status == SlotTemplateStatus.ready);
      bloc
        ..add(const SlotTemplateRangeChanged(start: ClockTime(18, 0)))
        ..add(const SlotTemplatePriceChanged(80000))
        ..add(const SlotTemplateDayToggled(0))
        ..add(const SlotTemplateDayToggled(6))
        ..add(const SlotTemplateApplyRequested());

      final state = await bloc.stream.firstWhere((s) => s.notice != null);

      expect(state.notice!.message, 'Đã áp dụng 40 slot cho 5 ngày trong tuần');
      verify(
        () => templates.applyTemplate(
          5,
          const SlotTemplateRequest(
            startTime: ClockTime(18, 0),
            endTime: ClockTime(22, 0),
            price: 80000,
            daysOfWeek: [1, 2, 3, 4, 5],
          ),
        ),
      ).called(1);
      await bloc.close();
    });

    test('áp dụng lỗi → thông báo lỗi', () async {
      when(() => templates.applyTemplate(5, any()))
          .thenThrow(const ServerFailure('Ngoài giờ', statusCode: 400));
      final bloc = build()..add(const SlotTemplateStarted());
      await bloc.stream.firstWhere((s) => s.status == SlotTemplateStatus.ready);

      bloc.add(const SlotTemplateApplyRequested());
      final state = await bloc.stream.firstWhere((s) => s.notice != null);

      expect(state.notice!.isError, isTrue);
      expect(state.applying, isFalse);
      await bloc.close();
    });
  });
}
