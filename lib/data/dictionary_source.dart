import 'dictionary_pack.dart';

/// Sumber kamus jarak jauh (Firestore).
abstract interface class DictionarySource {
  /// Mengunduh kamus versi terbaru. Mengembalikan null jika kamus belum
  /// dipublikasikan, atau jika versinya tidak lebih baru dari [ifNewerThan].
  /// Melempar error jika unduhan gagal atau datanya tidak konsisten.
  Future<DictionaryPack?> fetchLatest({int? ifNewerThan});
}
