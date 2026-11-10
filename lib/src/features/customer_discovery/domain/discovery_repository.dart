import 'discovery_filters.dart';
export 'discovery_filters.dart';
import '../../../../features/maps/domain/branch_location.dart';

class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.courtCount,
    this.district,
    this.minPrice,
    this.maxPrice,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.averageRating = 0,
    this.reviewCount = 0,
  });

  final int id;
  final String name, address, city;
  final String? district;
  final int courtCount;
  final String? imageUrl;
  final double averageRating;
  final int reviewCount;
  final double? minPrice, maxPrice, distanceKm;
  final double? latitude, longitude;
  BranchLocation? get location => BranchLocation.parse(latitude, longitude);
}

class BranchPage {
  const BranchPage({
    required this.branches,
    required this.page,
    required this.totalPages,
    required this.totalElements,
  });
  final List<Branch> branches;
  final int page, totalPages, totalElements;
  bool get hasNext => page + 1 < totalPages;
}

class Court {
  const Court({
    required this.id,
    required this.name,
    required this.courtTypeId,
    required this.defaultPricePerHour,
  });

  final int id;
  final String name;
  final int courtTypeId;
  final double? defaultPricePerHour;
}

/// IDs match subscription-service/database/V2__seed_sample_data.sql.
/// Deployments with another catalog can override the dart-defines.
enum DiscoverySport {
  badminton(
    'Cầu lông',
    int.fromEnvironment('BADMINTON_TYPE_ID', defaultValue: 6),
  ),
  pickleball(
    'Pickleball',
    int.fromEnvironment('PICKLEBALL_TYPE_ID', defaultValue: 1),
  ),
  tennis('Tennis', int.fromEnvironment('TENNIS_TYPE_ID', defaultValue: 3)),
  football('Bóng đá', int.fromEnvironment('FOOTBALL_TYPE_ID', defaultValue: 2));

  const DiscoverySport(this.label, this.typeId);
  final String label;
  final int typeId;
}

abstract interface class DiscoveryRepository {
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  });

  Future<List<Court>> courtsOfBranch(int branchId);
}

/// Facility metadata for a branch detail opened directly or after a reload.
abstract interface class BranchDetailRepository {
  Future<Branch> branchById(int branchId);
}
