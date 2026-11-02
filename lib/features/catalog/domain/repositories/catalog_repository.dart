import '../entities/court_type.dart';
import '../entities/court_type_input.dart';
import '../entities/page_result.dart';
import '../entities/subscription_plan.dart';
import '../entities/subscription_plan_input.dart';

/// Danh mục do super admin quản lý. Mọi phương thức ném `Failure` khi gọi API thất bại.
abstract class CatalogRepository {
  /// Lấy cả loại sân đang hoạt động lẫn đã tắt.
  Future<PageResult<CourtType>> courtTypes({required int page, required int size});

  /// Tạo mới khi [id] là `null`, ngược lại thay thế loại sân có [id].
  Future<CourtType> saveCourtType(CourtTypeInput input, {int? id});

  Future<void> deleteCourtType(int id);

  /// Lấy mọi gói chưa xóa, kể cả gói đã tắt.
  Future<PageResult<SubscriptionPlan>> plans({required int page, required int size});

  /// Tạo mới khi [id] là `null`, ngược lại thay thế gói có [id].
  Future<SubscriptionPlan> savePlan(SubscriptionPlanInput input, {int? id});

  Future<void> deletePlan(int id);
}
