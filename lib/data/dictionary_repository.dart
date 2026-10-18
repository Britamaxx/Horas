import '../models/dictionary_entry.dart';
import 'dictionary_index.dart';

abstract interface class DictionaryRepository {
  Future<List<DictionaryEntry>> loadEntries();

  /// Memuat kamus beserta indeks pencarian/kuis yang sudah dihitung.
  Future<DictionaryIndex> loadIndex();
}
