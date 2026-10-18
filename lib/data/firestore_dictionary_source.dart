import 'package:cloud_firestore/cloud_firestore.dart';

import 'dictionary_pack.dart';
import 'dictionary_source.dart';

/// Tata letak di Firestore (dibuat oleh `tools/publish_dictionary.py`):
///
///   dictionary_meta/current            { version, packCount, entryCount }
///   dictionary_packs/{version}_{000..} { version, index, entries: [...] }
///
/// Kamus dibagi menjadi sekitar belasan paket, jadi satu pemasangan baru
/// hanya membutuhkan packCount + 1 baca (bukan 14 ribu baca).
class FirestoreDictionarySource implements DictionarySource {
  FirestoreDictionarySource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const metaCollection = 'dictionary_meta';
  static const metaDocument = 'current';
  static const packCollection = 'dictionary_packs';

  final FirebaseFirestore _firestore;

  static String packId(int version, int index) =>
      '${version}_${index.toString().padLeft(3, '0')}';

  @override
  Future<DictionaryPack?> fetchLatest({int? ifNewerThan}) async {
    final metaSnapshot = await _firestore
        .collection(metaCollection)
        .doc(metaDocument)
        .get();
    final meta = metaSnapshot.data();
    if (meta == null) return null; // belum ada kamus yang dipublikasikan

    final version = _asInt(meta['version']);
    final packCount = _asInt(meta['packCount']);
    final entryCount = _asInt(meta['entryCount']);
    if (version == null || packCount == null || packCount <= 0) {
      throw const FormatException('Metadata kamus di Firestore tidak valid.');
    }
    if (ifNewerThan != null && version <= ifNewerThan) return null;

    final snapshots = await Future.wait([
      for (var i = 0; i < packCount; i++)
        _firestore.collection(packCollection).doc(packId(version, i)).get(),
    ]);

    final entries = <Map<String, Object?>>[];
    for (var i = 0; i < snapshots.length; i++) {
      final data = snapshots[i].data();
      if (data == null || _asInt(data['version']) != version) {
        throw StateError(
          'Paket kamus ${i + 1}/$packCount belum lengkap '
          '(mungkin sedang diperbarui). Coba lagi nanti.',
        );
      }
      final list = data['entries'];
      if (list is! List) {
        throw StateError('Paket kamus ${i + 1} tidak berisi daftar entri.');
      }
      for (final item in list) {
        if (item is Map) entries.add(Map<String, Object?>.from(item));
      }
    }

    if (entries.isEmpty ||
        (entryCount != null && entries.length != entryCount)) {
      throw StateError(
        'Jumlah entri kamus tidak cocok '
        '(diterima ${entries.length}, seharusnya $entryCount).',
      );
    }
    return DictionaryPack(version: version, entries: entries);
  }

  static int? _asInt(Object? value) => value is num ? value.toInt() : null;
}
