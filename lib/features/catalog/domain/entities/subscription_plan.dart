import 'package:equatable/equatable.dart';

/// Gói dịch vụ SaaS mà chủ sân mua. Giá tính bằng VND; `null` nghĩa là không bán theo chu kỳ đó.
class SubscriptionPlan extends Equatable {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.maxBranches,
    required this.maxCourts,
    required this.active,
    required this.popular,
    this.tagline,
    this.monthlyPrice,
    this.yearlyPrice,
    this.color,
    this.features = const [],
  });

  final int id;
  final String name;
  final int maxBranches;
  final int maxCourts;
  final bool active;
  final bool popular;
  final String? tagline;
  final int? monthlyPrice;
  final int? yearlyPrice;
  final String? color;
  final List<String> features;

  @override
  List<Object?> get props => [
        id,
        name,
        maxBranches,
        maxCourts,
        active,
        popular,
        tagline,
        monthlyPrice,
        yearlyPrice,
        color,
        features,
      ];
}
