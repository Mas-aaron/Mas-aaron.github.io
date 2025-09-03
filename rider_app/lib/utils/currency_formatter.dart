class CurrencyFormatter {
  /// Format amount as Ugandan Shillings (UGX)
  /// Example: 15000 -> "UGX 15,000"
  static String formatUGX(dynamic amount) {
    if (amount == null) return "UGX 0";
    
    // Convert to int for UGX (no decimal places)
    int ugxAmount = 0;
    if (amount is String) {
      ugxAmount = int.tryParse(amount) ?? 0;
    } else if (amount is double) {
      ugxAmount = amount.round();
    } else if (amount is int) {
      ugxAmount = amount;
    }
    
    // Format with commas
    String formatted = ugxAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    
    return "UGX $formatted";
  }
  
  /// Parse UGX string back to numeric amount
  /// Example: "UGX 15,000" -> 15000
  static int parseUGX(String ugxString) {
    if (ugxString.isEmpty) return 0;
    
    // Remove UGX prefix and commas
    String cleaned = ugxString
        .replaceAll('UGX', '')
        .replaceAll(',', '')
        .trim();
    
    return int.tryParse(cleaned) ?? 0;
  }
  
  /// Format amount for display in lists/cards
  /// Shorter format for space-constrained UI elements
  static String formatUGXCompact(dynamic amount) {
    if (amount == null) return "UGX 0";
    
    int ugxAmount = 0;
    if (amount is String) {
      ugxAmount = int.tryParse(amount) ?? 0;
    } else if (amount is double) {
      ugxAmount = amount.round();
    } else if (amount is int) {
      ugxAmount = amount;
    }
    
    if (ugxAmount >= 1000000) {
      double millions = ugxAmount / 1000000;
      return "UGX ${millions.toStringAsFixed(1)}M";
    } else if (ugxAmount >= 1000) {
      double thousands = ugxAmount / 1000;
      return "UGX ${thousands.toStringAsFixed(0)}K";
    }
    
    return "UGX $ugxAmount";
  }
}
