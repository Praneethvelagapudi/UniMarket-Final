import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/campus_policy.dart';

class AuthService {
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  AuthService(this.auth, this.db);
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(String uid) =>
      db.collection('users').doc(uid).snapshots(includeMetadataChanges: true);

  Future<void> login(String email, String password) async {
    final error = CampusPolicy.emailError(email);
    if (error != null) throw ArgumentError(error);
    await auth.signInWithEmailAndPassword(
      email: CampusPolicy.normalizeEmail(email),
      password: password,
    );
  }

  Future<void> register(
    String name,
    String roll,
    String email,
    String password,
  ) async {
    final error =
        CampusPolicy.rollError(roll) ??
        CampusPolicy.emailError(email, roll: roll);
    if (error != null) throw ArgumentError(error);
    if (name.trim().length < 2 || name.trim().length > 60) {
      throw ArgumentError('Enter a name between 2 and 60 characters.');
    }
    final result = await auth.createUserWithEmailAndPassword(
      email: CampusPolicy.normalizeEmail(email),
      password: password,
    );
    await result.user!.updateDisplayName(name.trim());
    await completeProfile(name, roll);
  }

  Future<void> completeProfile(String name, String roll) async {
    final user = auth.currentUser!;
    final error =
        CampusPolicy.rollError(roll) ??
        CampusPolicy.emailError(user.email, roll: roll);
    if (error != null) throw ArgumentError(error);
    await db
        .collection('users')
        .doc(user.uid)
        .set({
          'name': name.trim(),
          'roll': CampusPolicy.normalizeRoll(roll),
          'email': CampusPolicy.normalizeEmail(user.email!),
          'department': CampusPolicy.department(roll),
          'createdAt': FieldValue.serverTimestamp(),
        })
        // A first native connection can need extra time to establish its secure
        // Firestore channel. Keep a bound while allowing that initial handshake.
        .timeout(const Duration(seconds: 60));
  }

  Future<void> logout() => auth.signOut();
}
