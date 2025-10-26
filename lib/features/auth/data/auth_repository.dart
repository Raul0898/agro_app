import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/roles.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> signUp({
    required String email,
    required String password,
    required AppRole role,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.updateDisplayName(displayName ?? email.split('@').first);
    await _db.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'displayName': displayName ?? email.split('@').first,
      'role': roleToString(role),
      'createdAt': FieldValue.serverTimestamp(),
      'companyId': 'demoCo',
    });
  }

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  Future<AppRole?> getCurrentRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final d = await _db.collection('users').doc(uid).get();
    return roleFromString(d.data()?['role'] as String?);
  }
}
