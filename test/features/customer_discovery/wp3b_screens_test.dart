import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/customer_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/wp3b_shots.dart';
import '../auth/helpers.dart';

const _branch = Branch(
  id: 1,
  name: 'Sân Cầu Lông Ba Đình',
  address: '48 Vạn Bảo',
  district: 'Ba Đình',
  city: 'Hà Nội',
  courtCount: 2,
  minPrice: 50000,
  distanceKm: 1.2,
  averageRating: 4.6,
  reviewCount: 128,
);

class _Repo implements DiscoveryRepository {
  @override
  Future<List<Court>> courtsOfBranch(int branchId) async => const [
    Court(id: 1, name: 'Sân 1', courtTypeId: 6, defaultPricePerHour: 50000),
    Court(id: 2, name: 'Sân 2', courtTypeId: 6, defaultPricePerHour: 50000),
  ];

  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  }) async => const BranchPage(
    branches: [_branch],
    page: 0,
    totalPages: 1,
    totalElements: 1,
  );
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('home: hero, sport circles, photo card (${b.name})', (
      tester,
    ) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final auth = MockAuthRepository();
      when(() => auth.restoreSession()).thenAnswer((_) async => customerUser);
      final bloc = AuthBloc(RestoreSession(auth), Logout(auth))
        ..add(const AuthStarted());
      addTearDown(bloc.close);
      final key = await wp3bPump(
        tester,
        b,
        BlocProvider.value(
          value: bloc,
          child: wp3bShell(
            CustomerHomeScreen(repository: _Repo()),
            selected: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Hôm nay,\nmình chơi gì?'), findsOneWidget);
      expect(find.text('Sân nổi bật'), findsOneWidget);
      expect(find.text('Sân Cầu Lông Ba Đình'), findsOneWidget);
      expect(find.text('Từ 50.000đ/giờ'), findsOneWidget);
      await wp3bShot(tester, key, 'home-${b.name}');
    });

    testWidgets('branch detail: photo, info, courts, bottom bar (${b.name})', (
      tester,
    ) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final key = await wp3bPump(
        tester,
        b,
        back: true,
        BranchDetailScreen(
          branchId: 1,
          branch: _branch,
          discoveryRepository: _Repo(),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Sân Cầu Lông Ba Đình'), findsOneWidget);
      expect(find.text('Đặt sân'), findsOneWidget);
      expect(find.text('Từ 50.000đ/giờ'), findsOneWidget);
      await wp3bShot(tester, key, 'detail-${b.name}');
    });
  }
}
