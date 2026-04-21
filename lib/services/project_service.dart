class ProjectService {
  /// Generates project ID from company name + quote file name.
  /// Format: SVJM-{initials}-{number}
  /// e.g. "Bio Metric" + "Bio_Metric_001" → "SVJM-BM-001"
  static String generateProjectId(String company, String fileName) {
    final words = company.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .join();

    // Extract trailing number from fileName (e.g. "Bio_Metric_001" → "001")
    final match = RegExp(r'(\d+)$').firstMatch(fileName);
    final number = match != null ? match.group(1)! : '001';

    return 'SVJM-$initials-$number';
  }

  /// Calculates total budget from components list.
  static double totalBudget(List components) {
    double total = 0;
    for (final c in components) {
      final raw = (c['amount'] as String? ?? '').replaceAll(',', '').trim();
      total += double.tryParse(raw) ?? 0;
    }
    return total;
  }

  /// Calculates total spent from expenses list.
  static double totalSpent(List<Map<String, dynamic>> expenses) {
    double total = 0;
    for (final e in expenses) {
      total += (e['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  static String formatAmount(double amount) {
    // Indian number formatting
    final str = amount.toStringAsFixed(2);
    final parts = str.split('.');
    String intPart = parts[0];
    final decPart = parts[1];

    if (intPart.length <= 3) return '₹$intPart.$decPart';

    final last3 = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final formatted = rest.replaceAllMapped(
      RegExp(r'(\d{1,2})(?=(\d{2})+$)'),
      (m) => '${m[1]},',
    );
    return '₹$formatted,$last3.$decPart';
  }
}
