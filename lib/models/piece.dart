class PieceModification {
  const PieceModification({
    this.id,
    required this.name,
    required this.pricePerPiece,
    required this.appliedQuantity,
  });

  final int? id;
  final String name;
  final int pricePerPiece;
  final int appliedQuantity;

  int get subtotal => pricePerPiece * appliedQuantity;

  PieceModification copyWith({String? name, int? pricePerPiece, int? appliedQuantity}) {
    return PieceModification(
      id: id,
      name: name ?? this.name,
      pricePerPiece: pricePerPiece ?? this.pricePerPiece,
      appliedQuantity: appliedQuantity ?? this.appliedQuantity,
    );
  }
}

class Piece {
  const Piece({
    required this.id,
    required this.description,
    this.customerId,
    this.customerName,
    required this.quantity,
    required this.basePrice,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.modifications,
  });

  final int id;
  final String description;
  final int? customerId;
  final String? customerName;
  final int quantity;
  final int basePrice;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<PieceModification> modifications;

  bool get hasModifications => modifications.isNotEmpty;
  int get modificationsTotal => modifications.fold(0, (sum, m) => sum + m.subtotal);
  int get total => hasModifications ? modificationsTotal : quantity * basePrice;
  int get averagePerPiece => quantity == 0 ? 0 : (total / quantity).round();
}
