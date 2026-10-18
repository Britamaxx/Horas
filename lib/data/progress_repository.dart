import '../services/learning_progress_store.dart';

/// Penyimpanan progres per akun di server.
abstract interface class ProgressRepository {
  /// Progres yang sudah terkonfirmasi server (termasuk perubahan dari
  /// perangkat lain). Perubahan lokal yang belum terkirim tidak dipancarkan.
  Stream<ProgressSnapshot> watchProgress(String uid);

  Future<void> setEntrySaved(
    String uid,
    String entryId, {
    required bool saved,
  });

  Future<void> recordQuiz(String uid, int correct, int total);

  /// Memindahkan progres tamu ke akun (gabung, bukan timpa).
  Future<void> mergeGuestProgress(String uid, ProgressSnapshot guest);
}
