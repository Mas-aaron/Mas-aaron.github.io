class LoyaltyProfile {
  final int points;
  final int totalPointsEarned;
  final String tier;
  final String? nextTier;
  final double progress;
  final String benefits;

  LoyaltyProfile({
    required this.points,
    required this.totalPointsEarned,
    required this.tier,
    this.nextTier,
    required this.progress,
    required this.benefits,
  });

  factory LoyaltyProfile.fromJson(Map<String, dynamic> json) {
    return LoyaltyProfile(
      points: json['points'],
      totalPointsEarned: json['total_points_earned'],
      tier: json['tier'],
      nextTier: json['next_tier'],
      progress: (json['progress'] as num).toDouble(),
      benefits: json['benefits'],
    );
  }
}
