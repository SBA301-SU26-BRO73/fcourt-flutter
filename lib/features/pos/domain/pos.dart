class PosProduct {
  const PosProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.imageUrl,
  });
  final int id;
  final String name;
  final String category;
  final int price;
  final int stock;
  final String? imageUrl;
}

class PosLine {
  const PosLine(this.productId, this.name, this.quantity, this.total);
  final int productId;
  final String name;
  final int quantity;
  final int total;
}

class PosOrder {
  const PosOrder(this.id, this.code, this.status, this.total, this.lines);
  final int id;
  final String code;
  final String status;
  final int total;
  final List<PosLine> lines;
  bool get mayHandOver => status == 'PAID' || status == 'ON_BOOKING';
}

abstract class PosRepository {
  Future<List<PosProduct>> products({
    String query = '',
    String category = '',
    int offset = 0,
  });
  Future<PosOrder> create(
    Map<int, int> quantities,
    String method,
    int? bookingId,
    String key,
  );
  Future<PosOrder> order(int id);
  Future<List<PosOrder>> history({int offset = 0});
}
