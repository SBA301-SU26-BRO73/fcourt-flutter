import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_plan_input.dart';

class SubscriptionPlanModel {
  const SubscriptionPlanModel({
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

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlanModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        maxBranches: (json['maxBranches'] as num).toInt(),
        maxCourts: (json['maxCourts'] as num).toInt(),
        active: json['active'] as bool? ?? true,
        popular: json['popular'] as bool? ?? false,
        tagline: json['tagline'] as String?,
        monthlyPrice: (json['monthlyPrice'] as num?)?.toInt(),
        yearlyPrice: (json['yearlyPrice'] as num?)?.toInt(),
        color: json['color'] as String?,
        features: [
          for (final feature in (json['features'] as List<dynamic>? ?? const []))
            feature as String,
        ],
      );

  /// Body của `SubscriptionPlanRequest`. Sửa là thay thế toàn bộ nên luôn gửi đủ các trường.
  static Map<String, Object?> requestBody(SubscriptionPlanInput input) => {
        'name': input.name,
        'tagline': input.tagline,
        'monthlyPrice': input.monthlyPrice,
        'yearlyPrice': input.yearlyPrice,
        'maxBranches': input.maxBranches,
        'maxCourts': input.maxCourts,
        'features': input.features,
        'color': input.color,
        'popular': input.popular,
        'active': input.active,
      };

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

  SubscriptionPlan toEntity() => SubscriptionPlan(
        id: id,
        name: name,
        maxBranches: maxBranches,
        maxCourts: maxCourts,
        active: active,
        popular: popular,
        tagline: tagline,
        monthlyPrice: monthlyPrice,
        yearlyPrice: yearlyPrice,
        color: color,
        features: features,
      );
}
