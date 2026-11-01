import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_facility/data/repositories/catalog_court_type_repository.dart';
import 'package:fcourt/features/catalog/domain/entities/court_type.dart'
    as catalog;
import 'package:fcourt/features/catalog/domain/entities/page_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../catalog/helpers.dart';

catalog.CourtType type(int id, String name, {bool active = true}) =>
    catalog.CourtType(id: id, name: name, active: active);

PageResult<catalog.CourtType> page(
  List<catalog.CourtType> items, {
  int number = 0,
  int totalPages = 1,
}) => PageResult(
  items: items,
  page: number,
  totalPages: totalPages,
  totalElements: items.length,
);

void main() {
  late MockCatalogRepository catalogRepository;

  setUp(() => catalogRepository = MockCatalogRepository());

  test('lists active court types from every page of the catalog', () async {
    when(() => catalogRepository.courtTypes(page: 0, size: any(named: 'size')))
        .thenAnswer(
          (_) async => page([
            type(1, 'Pickleball'),
            type(2, 'Bóng đá mini', active: false),
          ], totalPages: 2),
        );
    when(() => catalogRepository.courtTypes(page: 1, size: any(named: 'size')))
        .thenAnswer(
          (_) async => page([type(7, 'Cờ vua')], number: 1, totalPages: 2),
        );

    final types = await CatalogCourtTypeRepository(
      catalogRepository,
    ).getCourtTypes();

    expect({for (final t in types) t.id: t.name}, {1: 'Pickleball', 7: 'Cờ vua'});
  });

  test('propagates catalog failures', () async {
    when(
      () => catalogRepository.courtTypes(page: 0, size: any(named: 'size')),
    ).thenThrow(const NetworkFailure());

    await expectLater(
      CatalogCourtTypeRepository(catalogRepository).getCourtTypes(),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
