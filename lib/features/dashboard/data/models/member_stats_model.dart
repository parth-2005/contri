import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/member_stats.dart';

/// Data Model for Member Statistics (Firestore)
/// Stores trust score tracking data in a subcollection: groups/{groupId}/memberStats/{userId}
class MemberStatsModel {
  final String userId;
  final String groupId;
  final double avgSettlementTimeHours;
  final int totalSettlements;
  final DateTime? lastSettlementDate;
  final DateTime? updatedAt;

  MemberStatsModel({
    required this.userId,
    required this.groupId,
    this.avgSettlementTimeHours = 0.0,
    this.totalSettlements = 0,
    this.lastSettlementDate,
    this.updatedAt,
  });

  /// Convert to Domain Entity
  MemberStats toEntity() {
    return MemberStats(
      userId: userId,
      groupId: groupId,
      avgSettlementTimeHours: avgSettlementTimeHours,
      totalSettlements: totalSettlements,
      lastSettlementDate: lastSettlementDate,
      updatedAt: updatedAt,
    );
  }

  /// Convert from Domain Entity
  factory MemberStatsModel.fromEntity(MemberStats stats) {
    return MemberStatsModel(
      userId: stats.userId,
      groupId: stats.groupId,
      avgSettlementTimeHours: stats.avgSettlementTimeHours,
      totalSettlements: stats.totalSettlements,
      lastSettlementDate: stats.lastSettlementDate,
      updatedAt: stats.updatedAt,
    );
  }

  /// Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'groupId': groupId,
      'avgSettlementTimeHours': avgSettlementTimeHours,
      'totalSettlements': totalSettlements,
      if (lastSettlementDate != null)
        'lastSettlementDate': Timestamp.fromDate(lastSettlementDate!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert from Firestore DocumentSnapshot
  factory MemberStatsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MemberStatsModel(
      userId: data['userId'] as String,
      groupId: data['groupId'] as String,
      avgSettlementTimeHours: (data['avgSettlementTimeHours'] as num?)?.toDouble() ?? 0.0,
      totalSettlements: (data['totalSettlements'] as num?)?.toInt() ?? 0,
      lastSettlementDate: data['lastSettlementDate'] != null
          ? (data['lastSettlementDate'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
