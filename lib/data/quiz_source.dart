import 'quiz_pack.dart';

/// Sumber bank soal jarak jauh (Firestore).
abstract interface class QuizSource {
  /// Mengunduh bank soal versi terbaru. Mengembalikan null jika belum
  /// dipublikasikan, atau jika versinya tidak lebih baru dari [ifNewerThan].
  /// Melempar error jika unduhan gagal atau datanya tidak konsisten.
  Future<QuizPack?> fetchLatest({int? ifNewerThan});
}
