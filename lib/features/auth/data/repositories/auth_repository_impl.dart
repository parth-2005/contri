import 'dart:async';
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
  bool _isInitialized = false;

  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize();
      _isInitialized = true;
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      await _ensureInitialized();

      // Trigger the authentication flow - this returns GoogleSignInAccount directly
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();

      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final user = userCredential.user!;

      final userModel = UserModel(
        id: user.uid,
        name: user.displayName ?? googleUser.displayName ?? 'Unknown',
        email: user.email ?? googleUser.email,
        photoUrl: user.photoURL ?? googleUser.photoUrl,
      );

      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(user.uid)
          .set(userModel.toFirestore(), SetOptions(merge: true));

      return userModel.toEntity();
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.disconnect(),
    ]);
  }

  @override
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;

      final doc = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        return AppUser(
          id: user.uid,
          name: user.displayName ?? 'Unknown',
          email: user.email ?? '',
          photoUrl: user.photoURL,
        );
      }

      return UserModel.fromFirestore(doc).toEntity();
    });
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return AppUser(
        id: user.uid,
        name: user.displayName ?? 'Unknown',
        email: user.email ?? '',
        photoUrl: user.photoURL,
      );
    }

    return UserModel.fromFirestore(doc).toEntity();
  }
}