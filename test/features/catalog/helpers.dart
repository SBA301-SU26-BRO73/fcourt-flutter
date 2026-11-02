import 'package:fcourt/features/catalog/domain/entities/court_type.dart';
import 'package:fcourt/features/catalog/domain/entities/page_result.dart';
import 'package:fcourt/features/catalog/domain/entities/subscription_plan.dart';
import 'package:fcourt/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

const badminton = CourtType(
  id: 1,
  name: 'Cầu lông',
  active: true,
  nameEn: 'Badminton',
  description: 'Sân cầu lông trong nhà',
  color: '#0B7A4B',
);

const football = CourtType(id: 2, name: 'Bóng đá mini', active: false);

const basicPlan = SubscriptionPlan(
  id: 1,
  name: 'Cơ bản',
  maxBranches: 1,
  maxCourts: 5,
  active: true,
  popular: false,
  tagline: 'Cho chủ sân nhỏ',
  monthlyPrice: 199000,
  yearlyPrice: 1990000,
  features: ['Quản lý đặt sân', 'Báo cáo doanh thu'],
);

const proPlan = SubscriptionPlan(
  id: 2,
  name: 'Chuyên nghiệp',
  maxBranches: 5,
  maxCourts: 50,
  active: false,
  popular: true,
  monthlyPrice: 999000,
);

PageResult<T> pageOf<T>(List<T> items, {int page = 0, int totalPages = 1, int? total}) =>
    PageResult(
      items: items,
      page: page,
      totalPages: totalPages,
      totalElements: total ?? items.length,
    );

Map<String, Object?> courtTypeJson({
  int id = 1,
  String name = 'Cầu lông',
  bool active = true,
  String? nameEn = 'Badminton',
}) =>
    {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'description': null,
      'icon': null,
      'color': '#0B7A4B',
      'active': active,
      'createdAt': '2026-10-01T00:00:00Z',
      'updatedAt': '2026-10-01T00:00:00Z',
    };

Map<String, Object?> planJson({
  int id = 1,
  String name = 'Cơ bản',
  int? monthlyPrice = 199000,
  int? yearlyPrice,
  List<String> features = const ['Quản lý đặt sân'],
}) =>
    {
      'id': id,
      'name': name,
      'tagline': 'Cho chủ sân nhỏ',
      'monthlyPrice': monthlyPrice,
      'yearlyPrice': yearlyPrice,
      'maxCourts': 5,
      'maxBranches': 1,
      'active': true,
      'color': null,
      'popular': false,
      'features': features,
      'createdAt': '2026-10-01T00:00:00Z',
      'updatedAt': '2026-10-01T00:00:00Z',
    };

Map<String, Object?> pageJson(
  List<Map<String, Object?>> content, {
  int page = 0,
  int size = 20,
  int totalPages = 1,
  int? totalElements,
}) =>
    {
      'content': content,
      'page': page,
      'size': size,
      'totalElements': totalElements ?? content.length,
      'totalPages': totalPages,
    };
