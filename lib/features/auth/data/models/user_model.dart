import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_user.dart';
import '../../../../core/constants/firebase_constants.dart';

/// Data Model for User (Firestore)
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final double totalOwed;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.totalOwed = 0.0,
  });

  /// Convert to Domain Entity
  AppUser toEntity() {
    return AppUser(
      id: id,
      name: name,
      email: email,
      photoUrl: photoUrl,
      totalOwed: totalOwed,
    );
  }

  /// Convert from Domain Entity
  factory UserModel.fromEntity(AppUser user) {
    return UserModel(
      id: user.id,
      name: user.name,
      email: user.email,
      photoUrl: user.photoUrl,
      totalOwed: user.totalOwed,
    );
  }

  /// Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.userNameField: name,
      FirebaseConstants.userEmailField: email,
      FirebaseConstants.userPhotoUrlField: photoUrl,
      FirebaseConstants.userTotalOwedField: totalOwed,
    };
  }

  /// Convert from Firestore DocumentSnapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data[FirebaseConstants.userNameField] as String,
      email: data[FirebaseConstants.userEmailField] as String,
      photoUrl: data[FirebaseConstants.userPhotoUrlField] as String?,
      totalOwed: (data[FirebaseConstants.userTotalOwedField] as num?)?.toDouble() ?? 0.0,
    );
  }
}
