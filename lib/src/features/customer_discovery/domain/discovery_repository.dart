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
  });

  final int id;
  final String name, address, city;
  final String? district;
  final int courtCount;
  final double? minPrice, maxPrice, distanceKm;
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
  tennis('Tennis', int.fromEnvironment('TENNIS_TYPE_ID', defaultValue: 3));

  const DiscoverySport(this.label, this.typeId);
  final String label;
  final int typeId;
}

abstract interface class DiscoveryRepository {
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    int page = 0,
  });
}
