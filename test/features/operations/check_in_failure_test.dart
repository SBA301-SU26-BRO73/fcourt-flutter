import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/operations/domain/check_in_failure.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _error(int status, Object? body) => DioException(
  requestOptions: RequestOptions(path: '/api/staff/check-in/preview'),
  response: Response(
    requestOptions: RequestOptions(path: '/api/staff/check-in/preview'),
    statusCode: status,
    data: body,
  ),
);

void main() {
  test(
    'generic English rejection becomes a Vietnamese message with causes',
    () {
      for (final status in [400, 404, 409]) {
        final failure = checkInFailureFromDio(
          _error(status, {'detail': 'Booking command rejected'}),
        );
        expect(failure, isA<ServerFailure>());
        expect(failure.message, isNot(contains('Booking command rejected')));
        expect(failure.message, contains('sai'));
        expect(failure.message, contains('chưa tới giờ'));
      }
    },
  );

  test('403 rejection mentions another branch', () {
    final failure = checkInFailureFromDio(
      _error(403, {'detail': 'Booking command rejected'}),
    );
    expect(failure.message, contains('chi nhánh khác'));
  });

  test('backend reason codes map to specific Vietnamese messages', () {
    String msg(String code) => checkInFailureFromDio(
      _error(409, {'detail': 'Booking command rejected', 'reason': code}),
    ).message;
    expect(msg('CHECKIN_TOO_EARLY'), contains('Chưa tới giờ'));
    expect(msg('WRONG_DATE'), contains('ngày'));
    expect(msg('WRONG_BRANCH'), contains('chi nhánh khác'));
    expect(msg('ALREADY_CHECKED_IN'), contains('đã được sử dụng'));
  });

  test(
    'other failures keep their own message and network errors pass through',
    () {
      expect(
        checkInFailureFromDio(_error(409, {'detail': 'Vé hết hạn'})).message,
        'Vé hết hạn',
      );
      expect(
        checkInFailureFromDio(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        ),
        isA<NetworkFailure>(),
      );
    },
  );

  test('unknown backend reason uses the generic Vietnamese fallback', () {
    final failure = checkInFailureFromDio(
      _error(409, {
        'detail': 'Booking command rejected',
        'reason': 'NEW_REASON',
      }),
    );
    expect(failure.message, contains('Không thể nhận sân'));
    expect(failure.message, isNot(contains('Booking command rejected')));
  });

  test('displayDate formats ISO dates as dd/MM/yyyy', () {
    expect(displayDate('2026-11-12'), '12/11/2026');
    expect(displayDate('hôm nay'), 'hôm nay');
  });
}
