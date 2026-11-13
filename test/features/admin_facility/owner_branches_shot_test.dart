import 'package:fcourt/features/admin_facility/domain/entities/branch.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/branch_list_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/branch_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/owner_shot.dart';
import 'mocks.dart';

Branch _branch(int id, String name, String address, String district, int n) =>
    Branch(
      id: id,
      name: name,
      address: address,
      district: district,
      city: 'Hà Nội',
      openTime: const ClockTime(6, 0),
      closeTime: const ClockTime(22, 0),
      bankName: 'VCB',
      bankBin: '970436',
      bankAccountNumber: '1',
      bankAccountName: 'A',
      status: BranchStatus.active,
      courtCount: n,
    );

void main() {
  for (final b in Brightness.values) {
    testWidgets('branch list matches the mock-up layout (${b.name})', (
      tester,
    ) async {
      final repo = MockBranchRepository();
      when(() => repo.getBranches()).thenAnswer(
        (_) async => [
          _branch(1, 'Sân Cầu Lông Ba Đình', '48 Vạn Bảo', 'Ba Đình', 6),
          _branch(2, 'Sân Tennis Tây Hồ', '28 Xuân Diệu', 'Tây Hồ', 4),
        ],
      );
      await pumpOwner(
        tester,
        b,
        BlocProvider(
          create: (_) =>
              BranchListBloc(GetBranches(repo))
                ..add(const BranchListRequested()),
          child: BranchListScreen(
            onCreateBranch: () async => null,
            onOpenBranch: (_) async {},
          ),
        ),
        navIndex: 2,
        shot: 'owner-branches',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Chi nhánh'), findsWidgets);
      expect(find.text('2 đang hoạt động'), findsOneWidget);
      expect(find.text('Sân Cầu Lông Ba Đình'), findsOneWidget);
      expect(find.text('Cầu lông'), findsOneWidget);
      expect(find.text('Tennis'), findsOneWidget);
      expect(find.text('+ Chi nhánh'), findsOneWidget);
      // Every branch card carries a photo, even without one of its own.
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is AssetImage),
        findsNWidgets(2),
      );
    });
  }
}
