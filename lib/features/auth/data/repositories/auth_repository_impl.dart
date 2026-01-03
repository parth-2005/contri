import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../../../../core/constants/firebase_constants.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthRepositoryImpl({
    FirebaseAuth firebaseAuth = FirebaseAuth.instance,
    FirebaseFirestore firestore = FirebaseFirestore.instance,
    GoogleSignIn googleSignIn = const GoogleSignIn(),
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore,
        _googleSignIn = googleSignIn;

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      // FIX 2: You MUST initialize before authenticating in v7
      await _googleSignIn.initialize(); 

      // FIX 3: Use authenticate() instead of signIn()
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();

      if (googleUser == null) {
        throw Exception('Sign-in cancelled by user');
      }

      // authentication returns a Future<GoogleSignInAuthentication>
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // FIX 4: Use idToken (accessToken is often null/unnecessary now)
      final credential = GoogleAuthProvider.credential(
        accessToken: null,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final user = userCredential.user!;

      final userModel = UserModel(
        id: user.uid,
        name: user.displayName ?? 'Unknown',
        email: user.email ?? '',
        photoUrl: user.photoURL,
      );

      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(user.uid)
          .set(userModel.toFirestore(), SetOptions(merge: true));

      return userModel.toEntity();
    } catch (e) {
      if (e.toString().contains('canceled') || e.toString().contains('cancelled')) {
        throw Exception('Sign-in cancelled');
      }
      throw Exception('Google Sign-In failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Initialize before disconnecting to avoid errors
      await _googleSignIn.initialize(); 
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.disconnect(),
      ]);
    } catch (e) {
      // Fallback if google sign out fails (e.g. not signed in)
      await _firebaseAuth.signOut();
    }
  }

  // ... (authStateChanges and getCurrentUser remain the same) ...
  @override
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      final doc = await _firestore.collection(FirebaseConstants.usersCollection).doc(user.uid).get();
      if (!doc.exists) {
        return AppUser(id: user.uid, name: user.displayName ?? 'Unknown', email: user.email ?? '', photoUrl: user.photoURL);
      }
      return UserModel.fromFirestore(doc).toEntity();
    });
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection(FirebaseConstants.usersCollection).doc(user.uid).get();
    if (!doc.exists) {
      return AppUser(id: user.uid, name: user.displayName ?? 'Unknown', email: user.email ?? '', photoUrl: user.photoURL);
    }
    return UserModel.fromFirestore(doc).toEntity();
  }

  // ⭐ NEW: Search user by Email (For adding members)
  @override
  Future<AppUser?> getUserByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .where(FirebaseConstants.userEmailField, isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return UserModel.fromFirestore(snapshot.docs.first).toEntity();
    } catch (e) {
      return null;
    }
  }

  // ⭐ FIXED: Fetch users in ONE Batch Request (Fast) instead of Loop (Slow)
  @override
  Future<List<AppUser>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      // Firestore 'whereIn' supports up to 10 items. 
      // For MVP, we take the first 10. In prod, you'd chunk this list.
      final idsToFetch = userIds.take(10).toList();

      final snapshot = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .where(FieldPath.documentId, whereIn: idsToFetch)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc).toEntity())
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ⭐ NEW: Update user profile
  @override
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData[FirebaseConstants.userNameField] = name;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (photoUrl != null) updateData[FirebaseConstants.userPhotoUrlField] = photoUrl;

      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(userId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
}
