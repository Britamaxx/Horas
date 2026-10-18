import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/app_user.dart';
import 'auth_repository.dart';

/// Implementasi [AuthRepository] memakai Firebase Authentication + provider Google.
///
/// Memakai alur provider bawaan Firebase (tanpa paket google_sign_in) supaya
/// satu kode yang sama jalan di Android dan web.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  // Kode error yang berarti pengguna sendiri menutup/membatalkan layar login.
  static const _cancelCodes = {
    'web-context-canceled',
    'web-context-cancelled',
    'popup-closed-by-user',
    'cancelled-popup-request',
    'canceled',
    'cancelled',
  };

  @override
  Stream<AppUser?> get authStateChanges =>
      _auth.authStateChanges().map(_toAppUser);

  @override
  Future<void> signInWithGoogle() async {
    final provider = fb.GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(provider);
      } else {
        await _auth.signInWithProvider(provider);
      }
    } on fb.FirebaseAuthException catch (error) {
      // Dibatalkan pengguna bukan kesalahan: diam saja, layar login tetap terbuka.
      if (_cancelCodes.contains(error.code)) return;
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AppUser? _toAppUser(fb.User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
      providerIds: user.providerData
          .map((info) => info.providerId)
          .toList(growable: false),
      createdAt: user.metadata.creationTime?.toUtc(),
      lastSignInAt: user.metadata.lastSignInTime?.toUtc(),
    );
  }
}
