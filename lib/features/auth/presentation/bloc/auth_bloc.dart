import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/restore_session.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Khởi động app: khôi phục phiên từ token đã lưu.
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Đăng nhập hoặc đăng ký khách hàng thành công.
class AuthSignedIn extends AuthEvent {
  const AuthSignedIn(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

/// Profile vừa được sửa.
class AuthUserUpdated extends AuthEvent {
  const AuthUserUpdated(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Refresh token thất bại: token đã bị xóa, chỉ cần đưa người dùng về đăng nhập.
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState._(this.status, this.user);

  const AuthState.unknown() : this._(AuthStatus.unknown, null);

  const AuthState.authenticated(AuthUser user)
      : this._(AuthStatus.authenticated, user);

  const AuthState.unauthenticated() : this._(AuthStatus.unauthenticated, null);

  final AuthStatus status;
  final AuthUser? user;

  UserRole? get role => user?.role;

  @override
  List<Object?> get props => [status, user];
}

/// Giữ phiên đăng nhập và vai trò hiện tại cho toàn app; router dựa vào đây để điều hướng.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._restoreSession, this._logout) : super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthSignedIn>((event, emit) => emit(AuthState.authenticated(event.user)));
    on<AuthUserUpdated>(_onUserUpdated);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>((event, emit) => emit(const AuthState.unauthenticated()));
  }

  final RestoreSession _restoreSession;
  final Logout _logout;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    try {
      final user = await _restoreSession();
      emit(user == null
          ? const AuthState.unauthenticated()
          : AuthState.authenticated(user));
    } on Failure {
      // Không hỏi được BE (mất mạng): vào màn đăng nhập, token vẫn được giữ.
      emit(const AuthState.unauthenticated());
    } catch (_) {
      // Lỗi bất ngờ (ví dụ Keystore không đọc được token): vẫn phải rời màn chờ,
      // nếu không app kẹt ở splash mãi.
      emit(const AuthState.unauthenticated());
    }
  }

  void _onUserUpdated(AuthUserUpdated event, Emitter<AuthState> emit) {
    if (state.status == AuthStatus.authenticated) {
      emit(AuthState.authenticated(event.user));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _logout();
    emit(const AuthState.unauthenticated());
  }
}
