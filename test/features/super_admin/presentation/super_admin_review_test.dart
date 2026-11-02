import 'dart:async';

import 'package:fcourt/features/super_admin/domain/entities/court_owner.dart';
import 'package:fcourt/features/super_admin/domain/repositories/court_owner_approval_repository.dart';
import 'package:fcourt/features/super_admin/domain/usecases/owner_approval_usecases.dart';
import 'package:fcourt/features/super_admin/presentation/bloc/owner_detail_cubit.dart';
import 'package:fcourt/features/super_admin/presentation/bloc/pending_owners_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements CourtOwnerApprovalRepository {}

CourtOwner owner(int id) => CourtOwner(
  id: id,
  email: 'o$id@fcourt.vn',
  fullName: 'Chủ sân $id',
  status: OwnerStatus.pendingApproval,
);

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  group('PendingOwnersCubit', () {
    test(
      'a load started before a decision does not bring the owner back',
      () async {
        final response = Completer<List<CourtOwner>>();
        when(() => repository.pendingOwners())
            .thenAnswer((_) => response.future);
        final cubit = PendingOwnersCubit(GetPendingOwners(repository));

        final loading = cubit.load();
        cubit.removeOwner(1);
        response.complete([owner(1), owner(2)]);
        await loading;

        expect(cubit.state.owners.map((o) => o.id), [2]);
        await cubit.close();
      },
    );

    test('an unexpected error ends loading with a failure state', () async {
      when(() => repository.pendingOwners()).thenThrow(StateError('boom'));
      final cubit = PendingOwnersCubit(GetPendingOwners(repository));

      await cubit.load();

      expect(cubit.state.status, PendingOwnersStatus.failure);
      expect(cubit.state.message, isNotEmpty);
      await cubit.close();
    });
  });

  group('OwnerDetailCubit', () {
    OwnerDetailCubit build() => OwnerDetailCubit(
      ownerId: 1,
      getOwnerDetail: GetOwnerDetail(repository),
      approveOwner: ApproveOwner(repository),
      rejectOwner: RejectOwner(repository),
    );

    test('an unexpected error while submitting releases the lock', () async {
      when(() => repository.ownerDetail(1)).thenAnswer((_) async => owner(1));
      when(() => repository.approve(1, reason: any(named: 'reason')))
          .thenThrow(StateError('boom'));
      final cubit = build();
      await cubit.load();

      await cubit.approve();

      expect(cubit.state.submitting, isFalse);
      expect(cubit.state.actionError, isNotEmpty);
      expect(cubit.state.decision, isNull);
      await cubit.close();
    });

    test(
      'an unexpected error while loading ends with a failure state',
      () async {
        when(() => repository.ownerDetail(1)).thenThrow(StateError('boom'));
        final cubit = build();

        await cubit.load();

        expect(cubit.state.status, OwnerDetailStatus.failure);
        expect(cubit.state.message, isNotEmpty);
        await cubit.close();
      },
    );
  });
}
