import 'package:flutter_test/flutter_test.dart';
import 'package:mikhyat_pro/models/piece.dart';

void main() {
  test('بدون تعديلات يستخدم سعر القطعة × العدد', () {
    final piece = Piece(
      id: 1,
      description: '',
      quantity: 3,
      basePrice: 200,
      createdAt: DateTime(2026, 8, 21),
      updatedAt: DateTime(2026, 8, 21),
      deletedAt: null,
      modifications: const [],
    );
    expect(piece.total, 600);
  });

  test('مع التعديلات لا يضاف السعر الأساسي', () {
    final piece = Piece(
      id: 1,
      description: '',
      quantity: 1,
      basePrice: 200,
      createdAt: DateTime(2026, 8, 21),
      updatedAt: DateTime(2026, 8, 21),
      deletedAt: null,
      modifications: const [PieceModification(name: 'الطول', pricePerPiece: 500, appliedQuantity: 1)],
    );
    expect(piece.total, 500);
  });

  test('كل تعديل يحسب على عدد القطع المحدد له', () {
    final piece = Piece(
      id: 1,
      description: '',
      quantity: 5,
      basePrice: 100,
      createdAt: DateTime(2026, 8, 21),
      updatedAt: DateTime(2026, 8, 21),
      deletedAt: null,
      modifications: const [
        PieceModification(name: 'الطول', pricePerPiece: 500, appliedQuantity: 3),
        PieceModification(name: 'العرض', pricePerPiece: 250, appliedQuantity: 2),
      ],
    );
    expect(piece.total, 2000);
  });
}
