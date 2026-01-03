import 'package:equatable/equatable.dart';

/// Member Statistics Entity for Trust Score Tracking
/// 
/// Tracks settlement behavior for "Shadow Analytics" (VC Bait)
/// - Average settlement time: How quickly member settles debts
/// - Total settlements: Number of payments made
/// - Trust score calculated from these metrics (not shown in UI yet)
class MemberStats extends Equatable {
  final String userId;
  final String groupId;
  
  /// Average time (in hours) it takes this member to settle debts
  /// Lower is better - indicates prompt payment behavior
  final double avgSettlementTimeHours;
  
  /// Total number of settlements/payments made by this member
  final int totalSettlements;
  
  /// Last settlement timestamp (for analytics)
  final DateTime? lastSettlementDate;
  
  /// Created/Updated timestamp
  final DateTime? updatedAt;

  const MemberStats({
    required this.userId,
    required this.groupId,
    this.avgSettlementTimeHours = 0.0,
    this.totalSettlements = 0,
    this.lastSettlementDate,
    this.updatedAt,
  });
  
  /// Calculate Trust Score (0-100)
  /// Formula: Base on quick settlements and frequency
  /// - Fast settlements (< 24 hours) = high score
  /// - Multiple settlements = reliability boost
  /// Not shown in UI yet - for future monetization/credit features
  double get trustScore {
    if (totalSettlements == 0) return 50.0; // Neutral score
    
    // Lower settlement time = better score
    double timeScore = 100.0;
    if (avgSettlementTimeHours > 0) {
      // Optimal: < 24 hours = 100, > 168 hours (1 week) = 20
      if (avgSettlementTimeHours <= 24) {
        timeScore = 100.0;
      } else if (avgSettlementTimeHours <= 168) {
        // Linear decay from 100 to 40 over 7 days
        timeScore = 100.0 - ((avgSettlementTimeHours - 24) / 144 * 60);
      } else {
        timeScore = 40.0 - ((avgSettlementTimeHours - 168) / 168 * 20);
        if (timeScore < 20) timeScore = 20.0;
      }
    }
    
    // Frequency bonus: More settlements = more reliable
    double frequencyBonus = 0.0;
    if (totalSettlements > 5) {
      frequencyBonus = 10.0;
    } else if (totalSettlements > 10) {
      frequencyBonus = 20.0;
    }
    
    final score = (timeScore + frequencyBonus).clamp(0.0, 100.0);
    return score.toDouble();
  }
  
  /// Human-readable trust level
  String get trustLevel {
    final score = trustScore;
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Improvement';
  }

  @override
  List<Object?> get props => [
    userId,
    groupId,
    avgSettlementTimeHours,
    totalSettlements,
    lastSettlementDate,
    updatedAt,
  ];
}
