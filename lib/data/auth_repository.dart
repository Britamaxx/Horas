import '../models/app_user.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> get authStateChanges;

  Future<void> signInWithGoogle();

  Future<void> signOut();
}
