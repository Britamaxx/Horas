import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import 'auth_repository.dart';

/// Implementasi [AuthRepository] memakai Firebase Authentication + provider Google.
///
/// Web memakai popup bawaan Firebase. Android memakai Google Sign-In native
/// (tanpa browser), lalu hasilnya ditukar menjadi kredensial Firebase.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  // google_sign_in wajib diinisialisasi tepat sekali sebelum dipakai.
  static Future<void>? _googleInit;
  static Future<void> _ensureGoogleInitialized() =>
      _googleInit ??= GoogleSignIn.instance.initialize();

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
    try {
      if (kIsWeb) {
        final provider = fb.GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile')
          ..setCustomParameters({'prompt': 'select_account'});
        await _auth.signInWithPopup(provider);
        return;
      }

      await _ensureGoogleInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw fb.FirebaseAuthException(
          code: 'missing-id-token',
          message: 'Google tidak mengirim ID token. Periksa SHA-1 dan google-services.json.',
        );
      }
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      // Dibatalkan pengguna bukan kesalahan: diam saja, layar login tetap terbuka.
      if (error.code == GoogleSignInExceptionCode.canceled) return;
      rethrow;
    } on fb.FirebaseAuthException catch (error) {
      if (_cancelCodes.contains(error.code)) return;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _ensureGoogleInitialized();
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Tetap lanjut keluar dari Firebase walau sesi Google gagal dibersihkan.
      }
    }
    await _auth.signOut();
  }

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
