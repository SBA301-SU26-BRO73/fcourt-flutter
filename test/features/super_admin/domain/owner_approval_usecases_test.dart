import 'package:fcourt/features/super_admin/domain/entities/court_owner.dart';
import 'package:fcourt/features/super_admin/domain/repositories/court_owner_approval_repository.dart';
import 'package:fcourt/features/super_admin/domain/usecases/owner_approval_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements CourtOwnerApprovalRepository {}

const _owner = CourtOwner(
  id: 1,
  email: 'a@fcourt.vn',
  fullName: 'A',
  status: OwnerStatus.rejected,
);

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  test('RejectOwner bỏ khoảng trắng trước khi gửi', () async {
    when(() => repository.reject(1, 'Ảnh mờ')).thenAnswer((_) async => _owner);

    await RejectOwner(repository)(1, '  Ảnh mờ  ');

    verify(() => repository.reject(1, 'Ảnh mờ')).called(1);
  });

  test('RejectOwner từ chối lý do rỗng hoặc quá 500 ký tự', () {
    expect(() => RejectOwner(repository)(1, '   '), throwsArgumentError);
    expect(
      () => RejectOwner(repository)(1, 'a' * (maxReasonLength + 1)),
      throwsArgumentError,
    );
    verifyNever(() => repository.reject(any(), any()));
  });

  test('ApproveOwner gửi null khi ghi chú rỗng', () async {
    when(() => repository.approve(1, reason: null))
        .thenAnswer((_) async => _owner);

    await ApproveOwner(repository)(1, reason: '  ');

    verify(() => repository.approve(1, reason: null)).called(1);
  });
}
