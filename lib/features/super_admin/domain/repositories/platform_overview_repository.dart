import '../entities/platform_overview.dart';

abstract interface class PlatformOverviewRepository {
  /// [months] số tháng gần nhất cho biểu đồ tăng trưởng (1..24).
  Future<PlatformOverview> overview({int months});
}

class GetPlatformOverview {
  const GetPlatformOverview(this._repository);

  final PlatformOverviewRepository _repository;

  Future<PlatformOverview> call({int months = 12}) =>
      _repository.overview(months: months);
}
