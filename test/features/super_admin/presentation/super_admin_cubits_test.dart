import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/super_admin/domain/entities/court_owner.dart';
import 'package:fcourt/features/super_admin/domain/repositories/court_owner_approval_repository.dart';
import 'package:fcourt/features/super_admin/domain/usecases/owner_approval_usecases.dart';
import 'package:fcourt/features/super_admin/presentation/bloc/owner_detail_cubit.dart';
import 'package:fcourt/features/super_admin/presentation/bloc/pending_owners_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements CourtOwnerApprovalRepository {}

CourtOwner owner(int id, [OwnerStatus status = OwnerStatus.pendingApproval]) =>
    CourtOwner(
      id: id,
      email: 'o$id@fcourt.vn',
      fullName: 'Chủ sân $id',
      status: status,
    );

const _conflict = ServerFailure(
  'Hồ sơ đã được xử lý. Vui lòng tải lại danh sách.',
  statusCode: 409,
);

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  group('PendingOwnersCubit', () {
    blocTest<PendingOwnersCubit, PendingOwnersState>(
      'loading rồi success với danh sách chờ duyệt',
      build: () {
        when(() => repository.pendingOwners())
            .thenAnswer((_) async => [owner(1), owner(2)]);
        return PendingOwnersCubit(GetPendingOwners(repository));
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const PendingOwnersState(status: PendingOwnersStatus.loading),
        PendingOwnersState(
          status: PendingOwnersStatus.success,
          owners: [owner(1), owner(2)],
        ),
      ],
    );

    blocTest<PendingOwnersCubit, PendingOwnersState>(
      'giữ danh sách cũ khi tải lại lỗi',
      build: () {
        when(() => repository.pendingOwners())
            .thenThrow(const NetworkFailure());
        return PendingOwnersCubit(GetPendingOwners(repository));
      },
      seed: () => PendingOwnersState(
        status: PendingOwnersStatus.success,
        owners: [owner(1)],
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        PendingOwnersState(
          status: PendingOwnersStatus.loading,
          owners: [owner(1)],
        ),
        PendingOwnersState(
          status: PendingOwnersStatus.failure,
          owners: [owner(1)],
          message: 'Không kết nối được máy chủ',
        ),
      ],
    );

    blocTest<PendingOwnersCubit, PendingOwnersState>(
      'removeOwner bỏ hồ sơ khỏi danh sách ngay',
      build: () => PendingOwnersCubit(GetPendingOwners(repository)),
      seed: () => PendingOwnersState(
        status: PendingOwnersStatus.success,
        owners: [owner(1), owner(2)],
      ),
      act: (cubit) => cubit.removeOwner(1),
      expect: () => [
        PendingOwnersState(
          status: PendingOwnersStatus.success,
          owners: [owner(2)],
        ),
      ],
    );
  });

  group('OwnerDetailCubit', () {
    OwnerDetailCubit build() => OwnerDetailCubit(
      ownerId: 1,
      getOwnerDetail: GetOwnerDetail(repository),
      approveOwner: ApproveOwner(repository),
      rejectOwner: RejectOwner(repository),
    );

    blocTest<OwnerDetailCubit, OwnerDetailState>(
      'tải chi tiết hồ sơ',
      build: () {
        when(() => repository.ownerDetail(1)).thenAnswer((_) async => owner(1));
        return build();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const OwnerDetailState(),
        OwnerDetailState(status: OwnerDetailStatus.loaded, owner: owner(1)),
      ],
    );

    blocTest<OwnerDetailCubit, OwnerDetailState>(
      'duyệt thành công trả về decision',
      build: () {
        when(() => repository.approve(1, reason: null))
            .thenAnswer((_) async => owner(1, OwnerStatus.active));
        return build();
      },
      seed: () =>
          OwnerDetailState(status: OwnerDetailStatus.loaded, owner: owner(1)),
      act: (cubit) => cubit.approve(reason: ''),
      expect: () => [
        OwnerDetailState(
          status: OwnerDetailStatus.loaded,
          owner: owner(1),
          submitting: true,
        ),
        OwnerDetailState(
          status: OwnerDetailStatus.loaded,
          owner: owner(1, OwnerStatus.active),
          decision: OwnerDecision(
            owner: owner(1, OwnerStatus.active),
            type: OwnerDecisionType.approved,
          ),
        ),
      ],
    );

    blocTest<OwnerDetailCubit, OwnerDetailState>(
      'từ chối lỗi 409 giữ hồ sơ và báo actionError',
      build: () {
        when(() => repository.reject(1, 'Sai')).thenThrow(_conflict);
        return build();
      },
      seed: () =>
          OwnerDetailState(status: OwnerDetailStatus.loaded, owner: owner(1)),
      act: (cubit) => cubit.reject('Sai'),
      expect: () => [
        OwnerDetailState(
          status: OwnerDetailStatus.loaded,
          owner: owner(1),
          submitting: true,
        ),
        OwnerDetailState(
          status: OwnerDetailStatus.loaded,
          owner: owner(1),
          actionError: _conflict.message,
        ),
      ],
    );
  });
}
