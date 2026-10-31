import 'package:fcourt/features/admin_facility/domain/entities/branch.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/court.dart';
import 'package:fcourt/features/admin_facility/domain/entities/slot_template.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/apply_slot_template.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/court_usecases.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/branch_form_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/branch_list_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/court_form_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/court_list_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/slot_template_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/branch_form_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/branch_list_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/court_form_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/court_list_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/time_slot_template_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures.dart';
import '../mocks.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

/// Mở [screen] bằng Navigator.push để kiểm tra giá trị trả về khi pop.
Widget _launcher(Widget screen, void Function(Object?) onResult) => Builder(
  builder: (context) => Scaffold(
    body: TextButton(
      onPressed: () async => onResult(
        await Navigator.of(context)
            .push<Object?>(MaterialPageRoute(builder: (_) => screen)),
      ),
      child: const Text('open'),
    ),
  ),
);

Branch _branchWith({required ClockTime open, required ClockTime close}) {
  final b = sampleBranch();
  return Branch(
    id: b.id,
    name: b.name,
    address: b.address,
    city: b.city,
    district: b.district,
    openTime: open,
    closeTime: close,
    bankName: b.bankName,
    bankBin: b.bankBin,
    bankAccountNumber: b.bankAccountNumber,
    bankAccountName: b.bankAccountName,
    status: b.status,
    courtCount: b.courtCount,
  );
}

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

  group('SCRUM-15 chi nhánh', () {
    testWidgets('thẻ chi nhánh có địa chỉ, giờ mở cửa và số sân; tạo mới '
        'thì tải lại và chúc mừng', (tester) async {
      when(() => branches.getBranches())
          .thenAnswer((_) async => [sampleBranch()]);
      await _pump(
        tester,
        BlocProvider(
          create: (_) =>
              BranchListBloc(GetBranches(branches))
                ..add(const BranchListRequested()),
          child: BranchListScreen(
            onCreateBranch: () async => sampleBranch(id: 2, name: 'FCourt Mới'),
            onEditBranch: (_) async => null,
            onOpenCourts: (_) {},
          ),
        ),
      );

      expect(find.text('FCourt Quận 7'), findsOneWidget);
      expect(
        find.text('12 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh'),
        findsOneWidget,
      );
      expect(find.text('Mở cửa 06:00 – 22:00'), findsOneWidget);
      expect(find.text('4 sân'), findsOneWidget);

      await tester.tap(find.text('Thêm chi nhánh'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Chúc mừng!'), findsOneWidget);
      expect(find.byIcon(Icons.celebration), findsOneWidget);
      verify(() => branches.getBranches()).called(2);
    });

    testWidgets('form tạo mới báo lỗi các trường bắt buộc, không gọi API', (
      tester,
    ) async {
      await _pump(
        tester,
        BlocProvider(
          create: (_) => BranchFormBloc(
            getBranch: GetBranch(branches),
            saveBranch: SaveBranch(branches),
          ),
          child: const BranchFormScreen(),
        ),
      );

      await tester.tap(find.byKey(const Key('branch-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập tên chi nhánh'), findsOneWidget);
      expect(find.text('Vui lòng nhập địa chỉ'), findsOneWidget);
      expect(find.text('Vui lòng chọn tỉnh/thành'), findsOneWidget);
      expect(find.text('Vui lòng chọn ngân hàng'), findsOneWidget);
      expect(find.text('Vui lòng nhập số tài khoản'), findsOneWidget);
      verifyNever(() => branches.createBranch(any()));
    });

    testWidgets('giờ đóng trước giờ mở và số tài khoản sai bị chặn', (
      tester,
    ) async {
      when(() => branches.getBranch(1)).thenAnswer(
        (_) async => _branchWith(
          open: const ClockTime(22, 0),
          close: const ClockTime(6, 0),
        ),
      );
      await _pump(
        tester,
        BlocProvider(
          create: (_) => BranchFormBloc(
            getBranch: GetBranch(branches),
            saveBranch: SaveBranch(branches),
            branchId: 1,
          )..add(const BranchFormStarted()),
          child: const BranchFormScreen(),
        ),
      );
      await tester.enterText(find.byKey(const Key('branch-account')), '123ab');
      await tester.tap(find.byKey(const Key('branch-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Giờ đóng cửa phải sau giờ mở cửa'), findsOneWidget);
      // Ký tự chữ bị lọc, còn "123" → quá ngắn.
      expect(
        find.text('Số tài khoản gồm 6–20 chữ số, không có ký tự khác'),
        findsOneWidget,
      );
      verifyNever(() => branches.updateBranch(any(), any()));
    });

    testWidgets('sửa hợp lệ gọi PUT và trả chi nhánh về màn trước', (
      tester,
    ) async {
      when(() => branches.getBranch(1)).thenAnswer((_) async => sampleBranch());
      when(() => branches.updateBranch(1, any()))
          .thenAnswer((_) async => sampleBranch(name: 'Đã sửa'));
      Object? result;
      await _pump(
        tester,
        _launcher(
          BlocProvider(
            create: (_) => BranchFormBloc(
              getBranch: GetBranch(branches),
              saveBranch: SaveBranch(branches),
              branchId: 1,
            )..add(const BranchFormStarted()),
            child: const BranchFormScreen(),
          ),
          (value) => result = value,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('branch-name')), 'Đã sửa');
      await tester.tap(find.byKey(const Key('branch-submit')));
      await tester.pumpAndSettle();

      expect(result, sampleBranch(name: 'Đã sửa'));
      final sent =
          verify(() => branches.updateBranch(1, captureAny())).captured.single
              as BranchDraft;
      expect(sent.name, 'Đã sửa');
      expect(sent.bankBin, '970436');
    });
  });

  group('SCRUM-17 sân', () {
    Widget courtList({Future<Court?> Function(int)? onCreate}) => BlocProvider(
      create: (_) => CourtListBloc(
        getBranches: GetBranches(branches),
        getCourts: GetCourts(courts),
        getCourtTypes: GetCourtTypes(types),
        toggleMaintenance: ToggleCourtMaintenance(courts),
      )..add(const CourtListStarted(1)),
      child: CourtListScreen(
        onCreateCourt: onCreate ?? (_) async => null,
        onEditCourt: (_) async => null,
        onOpenSlotTemplate: (_) {},
      ),
    );

    setUp(() {
      when(() => branches.getBranches())
          .thenAnswer((_) async => [sampleBranch()]);
      when(() => courts.getCourts(1)).thenAnswer(
        (_) async => [
          sampleCourt(),
          sampleCourt(id: 6, status: CourtStatus.maintenance),
          sampleCourt(id: 7, status: CourtStatus.inactive),
        ],
      );
    });

    testWidgets('lưới 2 cột có nhãn trạng thái và bộ lọc chi nhánh', (
      tester,
    ) async {
      await _pump(tester, courtList());

      expect(find.text('FCourt Quận 7'), findsOneWidget);
      expect(find.text('Hoạt động'), findsOneWidget);
      expect(find.text('Bảo trì'), findsWidgets);
      expect(find.text('Đang đóng'), findsOneWidget);
      expect(find.text('Cầu lông'), findsNWidgets(3));
      expect(find.text('120.000 đ/giờ'), findsNWidgets(3));
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
    });

    testWidgets('Switch bảo trì cập nhật nhãn và hiện SnackBar', (
      tester,
    ) async {
      when(
        () => courts.changeStatus(5, CourtStatus.maintenance),
      ).thenAnswer((_) async => sampleCourt(status: CourtStatus.maintenance));
      await _pump(tester, courtList());

      await tester.tap(find.byKey(const Key('court-maintenance-5')));
      await tester.pumpAndSettle();

      expect(find.text('Đã chuyển "Sân 5" sang bảo trì'), findsOneWidget);
      expect(find.text('Hoạt động'), findsNothing);
    });

    testWidgets('sân vừa tạo xuất hiện ngay trên lưới', (tester) async {
      await _pump(
        tester,
        courtList(onCreate: (_) async => sampleCourt(id: 8, name: 'Sân VIP')),
      );

      await tester.tap(find.text('Thêm sân'));
      await tester.pumpAndSettle();

      expect(find.text('Sân VIP'), findsOneWidget);
      expect(find.text('Đã thêm sân "Sân VIP"'), findsOneWidget);
    });

    testWidgets('form sân kiểm tra tên, loại sân và giá > 0', (tester) async {
      await _pump(
        tester,
        BlocProvider(
          create: (_) => CourtFormBloc(
            getCourt: GetCourt(courts),
            saveCourt: SaveCourt(courts),
            getCourtTypes: GetCourtTypes(types),
            branchId: 1,
          )..add(const CourtFormStarted()),
          child: const CourtFormScreen(),
        ),
      );

      await tester.tap(find.byKey(const Key('court-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập tên sân'), findsOneWidget);
      expect(find.text('Vui lòng chọn loại sân'), findsOneWidget);
      expect(find.text('Vui lòng nhập giá'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('court-price')), '0');
      await tester.pumpAndSettle();
      expect(find.text('Giá phải lớn hơn 0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('court-type')));
      await tester.pumpAndSettle();
      for (final type in ['Cầu lông', 'Pickleball', 'Tennis']) {
        expect(find.text(type), findsWidgets);
      }
      verifyNever(() => courts.createCourt(any(), any()));
    });
  });

  group('SCRUM-19 mẫu khung giờ', () {
    Widget screen() => BlocProvider(
      create: (_) => SlotTemplateBloc(
        courtId: 5,
        getCourt: GetCourt(courts),
        getBranch: GetBranch(branches),
        applyTemplate: ApplySlotTemplate(templates),
      )..add(const SlotTemplateStarted()),
      child: const TimeSlotTemplateScreen(),
    );

    setUp(() {
      when(() => courts.getCourt(5)).thenAnswer((_) async => sampleCourt());
      when(() => branches.getBranch(1)).thenAnswer((_) async => sampleBranch());
    });

    testWidgets('xem trước đủ slot trong ngày kèm giá', (tester) async {
      await _pump(tester, screen());

      expect(find.text('Xem trước: 32 slot/ngày'), findsOneWidget);
      expect(find.text('06:00–06:30'), findsOneWidget);
      expect(find.text('60.000 đ'), findsWidgets);
      expect(find.text('30 phút (chuẩn)'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('slot-price')), '75000');
      await tester.pumpAndSettle();
      expect(find.text('75.000 đ'), findsWidgets);
      expect(find.text('60.000 đ'), findsNothing);
    });

    testWidgets('cảnh báo khi giờ kết thúc sớm hơn giờ bắt đầu', (
      tester,
    ) async {
      await _pump(tester, screen());
      final bloc = BlocProvider.of<SlotTemplateBloc>(
        tester.element(find.byType(TimeSlotTemplateScreen)),
      );

      bloc.add(const SlotTemplateRangeChanged(end: ClockTime(5, 0)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slot-warning')), findsOneWidget);
      expect(find.textContaining('sớm hơn'), findsOneWidget);
      expect(find.text('Xem trước: 0 slot/ngày'), findsOneWidget);
      final apply = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('slot-apply')),
      );
      expect(apply.onPressed, isNull);
    });

    testWidgets('Áp dụng cho sân hỏi xác nhận rồi gọi apply-template', (
      tester,
    ) async {
      when(() => templates.applyTemplate(5, any())).thenAnswer(
        (_) async => const AppliedTemplate(
          courtId: 5,
          daysOfWeek: [0, 1, 2, 3, 4, 5, 6],
          totalSlots: 224,
        ),
      );
      await _pump(tester, screen());

      await tester.tap(find.byKey(const Key('slot-apply')));
      await tester.pumpAndSettle();
      expect(find.text('Áp dụng mẫu khung giờ?'), findsOneWidget);
      verifyNever(() => templates.applyTemplate(any(), any()));

      await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng'));
      await tester.pumpAndSettle();

      expect(
        find.text('Đã áp dụng 224 slot cho 7 ngày trong tuần'),
        findsOneWidget,
      );
      verify(() => templates.applyTemplate(5, any())).called(1);
    });
  });
}
