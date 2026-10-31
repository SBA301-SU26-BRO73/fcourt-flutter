import '../../domain/entities/court_type.dart';

/// Danh mục loại sân tạm thời, theo seed của subscription-service
/// (`V2__seed_sample_data.sql`): Pickleball=1, Tennis=3, Cầu lông=6.
///
/// Chưa có API catalog (SCRUM-10/11). Khi có, thay bằng data source gọi API
/// mà không phải sửa tầng domain/presentation.
class CourtTypeLocalDataSource {
  const CourtTypeLocalDataSource();

  static const types = <CourtType>[
    CourtType(id: 6, name: 'Cầu lông'),
    CourtType(id: 1, name: 'Pickleball'),
    CourtType(id: 3, name: 'Tennis'),
  ];

  List<CourtType> getCourtTypes() => types;
}
