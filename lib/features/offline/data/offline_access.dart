import '../../auth/domain/entities/auth_user.dart';
import '../../auth/domain/entities/user_role.dart';
import 'offline_coordinator.dart';

/// A local admission capability, never a general authenticated session.
class OfflineAccess {
  const OfflineAccess(this.coordinator);
  final OfflineCoordinator coordinator;
  Future<AuthUser?> restore() async {
    final scope = await coordinator.cachedScope();
    if (scope == null) return null;
    return AuthUser(
      id: scope.userId,
      email: '',
      role: UserRole.staff,
      status: 'ACTIVE',
      fullName: 'Nhân viên ngoại tuyến',
    );
  }
}
