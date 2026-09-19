class MerchantRule {
  const MerchantRule({
    required this.id,
    required this.pattern,
    required this.category,
    required this.accountId,
    required this.merchant,
    required this.useCount,
    required this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String pattern;
  final String category;
  final int? accountId;
  final String? merchant;
  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

abstract interface class MerchantRuleRepository {
  Stream<List<MerchantRule>> watchAll();
  Future<List<MerchantRule>> getAll();
  Future<void> learn({
    required String pattern,
    required String category,
    int? accountId,
    String? merchant,
  });
  Future<bool> delete(int id);
  Future<void> clear();
}
