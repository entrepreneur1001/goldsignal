// A weight-based savings goal (e.g. "save 100g of gold"). Progress is derived
// from the user's portfolio holdings of the same metal.
//
// Stored as a plain JSON map in the `savingsGoals` Hive box (same pattern as
// PriceAlert / userAlerts — no TypeAdapters or codegen).

class SavingsGoal {
  final String id;
  final String metal; // 'Gold' | 'Silver'
  final double targetGrams;
  final DateTime createdAt;
  final String? note;

  const SavingsGoal({
    required this.id,
    required this.metal,
    required this.targetGrams,
    required this.createdAt,
    this.note,
  });

  SavingsGoal copyWith({
    String? metal,
    double? targetGrams,
    String? note,
  }) {
    return SavingsGoal(
      id: id,
      metal: metal ?? this.metal,
      targetGrams: targetGrams ?? this.targetGrams,
      createdAt: createdAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'metal': metal,
        'targetGrams': targetGrams,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as String,
      metal: json['metal'] as String? ?? 'Gold',
      targetGrams: (json['targetGrams'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      note: json['note'] as String?,
    );
  }
}
