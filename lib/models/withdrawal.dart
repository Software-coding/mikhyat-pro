class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.amount,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final int id;
  final int amount;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}
