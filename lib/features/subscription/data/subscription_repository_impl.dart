import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/remote_call.dart';
import '../../catalog/domain/entities/subscription_plan.dart';
import '../domain/subscription.dart';
import 'subscription_models.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  const SubscriptionRepositoryImpl(this.dio);
  final Dio dio;
  Future<T> _call<T>(Future<T> Function() operation) => remoteCall(
    operation,
    localize: (error) => ServerFailure(switch (error.statusCode) {
      403 => 'Bạn không có quyền quản lý gói dịch vụ này.',
      404 => 'Không tìm thấy gói hoặc giao dịch trong tài khoản của bạn.',
      409 => 'Hiện chưa có gói dịch vụ phù hợp. Vui lòng tải lại danh sách.',
      502 || 503 => 'Dịch vụ thanh toán chưa sẵn sàng. Vui lòng thử lại sau.',
      _ => error.message,
    }, statusCode: error.statusCode),
  );

  @override
  Future<List<SubscriptionPlan>> plans() => _call(() async {
    final raw = (await dio.get<dynamic>(
      '/api/subscription-plans/all',
      options: Options(headers: {'Cache-Control': 'no-cache'}),
    )).data;
    if (raw is! List) throw const FormatException();
    final plans = raw.map(SubscriptionModels.plan).toList();
    if (plans.any((p) => !p.active) ||
        plans.map((p) => p.id).toSet().length != plans.length) {
      throw const FormatException();
    }
    return List.unmodifiable(plans);
  });
  @override
  Future<OwnerSubscription> current() => _call(
    () async => SubscriptionModels.subscription(
      (await dio.get<dynamic>(
        '/api/subscriptions/my-subscription',
        options: Options(headers: {'Cache-Control': 'no-cache'}),
      )).data,
    ),
  );
  @override
  Future<SubscriptionPayment> checkout(int planId, BillingCycle cycle) async {
    if (planId <= 0) throw const ServerFailure('Gói dịch vụ không hợp lệ');
    return _call(() async {
      final result = SubscriptionModels.payment(
        (await dio.post<dynamic>(
          '/api/subscriptions/checkout',
          data: {'planId': planId, 'billingCycle': cycle.api},
        )).data,
      );
      if (result.planId != planId || result.cycle != cycle) {
        throw const FormatException();
      }
      return result;
    });
  }

  @override
  Future<SubscriptionPayment> payment(int orderCode) async {
    if (orderCode <= 0) throw const ServerFailure('Giao dịch không hợp lệ');
    return _call(() async {
      final result = SubscriptionModels.payment(
        (await dio.get<dynamic>(
          '/api/subscriptions/payments/$orderCode',
          options: Options(headers: {'Cache-Control': 'no-cache'}),
        )).data,
      );
      if (result.orderCode != orderCode) throw const FormatException();
      return result;
    });
  }
}
