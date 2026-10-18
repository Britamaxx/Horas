import 'dictionary_index.dart';
import 'dictionary_pack.dart';

class CachedDictionary {
  const CachedDictionary({required this.version, required this.index});

  final int version;
  final DictionaryIndex index;
}

/// Salinan kamus di perangkat supaya aplikasi terbuka instan dan jalan offline.
abstract interface class DictionaryCache {
  /// Null jika belum ada salinan atau salinannya rusak.
  Future<CachedDictionary?> load();

  /// Menyimpan paket ke perangkat.
  Future<void> save(DictionaryPack pack);

  /// Menyimpan paket, lalu mengembalikan indeks yang sudah dibangun.
  Future<DictionaryIndex> saveAndBuildIndex(DictionaryPack pack);
}
