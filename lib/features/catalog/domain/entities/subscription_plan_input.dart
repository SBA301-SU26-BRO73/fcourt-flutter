import 'package:equatable/equatable.dart';

/// Dữ liệu form tạo hoặc sửa gói dịch vụ. Giá `null` nghĩa là không bán theo chu kỳ đó.
class SubscriptionPlanInput extends Equatable {
  const SubscriptionPlanInput({
    required this.name,
    required this.maxBranches,
    required this.maxCourts,
    this.tagline,
    this.monthlyPrice,
    this.yearlyPrice,
    this.features = const [],
    this.color,
    this.popular = false,
    this.active = true,
  });

  final String name;
  final int maxBranches;
  final int maxCourts;
  final String? tagline;
  final int? monthlyPrice;
  final int? yearlyPrice;
  final List<String> features;
  final String? color;
  final bool popular;
  final bool active;

  @override
  List<Object?> get props => [
        name,
        maxBranches,
        maxCourts,
        tagline,
        monthlyPrice,
        yearlyPrice,
        features,
        color,
        popular,
        active,
      ];
}
