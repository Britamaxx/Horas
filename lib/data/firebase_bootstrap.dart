import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'auth_repository.dart';
import 'dictionary_source.dart';
import 'firebase_auth_repository.dart';
import 'firestore_dictionary_source.dart';
import 'firestore_progress_repository.dart';
import 'firestore_quiz_source.dart';
import 'firestore_user_profile_repository.dart';
import 'progress_repository.dart';
import 'quiz_source.dart';
import 'user_profile_repository.dart';

class FirebaseBackend {
  const FirebaseBackend({
    required this.auth,
    required this.profiles,
    required this.progress,
    required this.dictionary,
    required this.quiz,
  });

  final AuthRepository auth;
  final UserProfileRepository profiles;
  final ProgressRepository progress;
  final DictionarySource dictionary;
  final QuizSource quiz;
}

/// Menginisialisasi Firebase. Jika belum dikonfigurasi atau gagal, hasilnya
/// null dan aplikasi tetap berjalan dalam mode lokal. Tidak pernah melempar
/// error, jadi aman dijalankan paralel dengan pemuatan kamus.
Future<FirebaseBackend?> initializeFirebaseBackend() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    return FirebaseBackend(
      auth: FirebaseAuthRepository(),
      profiles: FirestoreUserProfileRepository(),
      progress: FirestoreProgressRepository(),
      dictionary: FirestoreDictionarySource(),
      quiz: FirestoreQuizSource(),
    );
  } catch (error) {
    debugPrint('Firebase tidak aktif, memakai mode lokal: $error');
    return null;
  }
}
