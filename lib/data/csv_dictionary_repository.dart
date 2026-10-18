import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';

import '../models/dictionary_entry.dart';
import 'csv_dictionary_parser.dart';
import 'dictionary_index.dart';
import 'dictionary_repository.dart';

/// Kamus dimuat dari aset CSV yang ikut terpasang di aplikasi.
///
/// Sengaja TIDAK dari Firestore: 14 ribu entri akan menghabiskan kuota baca
/// tiap kali dibuka, butuh internet, dan Firestore tidak bisa mencari di
/// dalam arti (hanya awalan kata). Firestore dipakai untuk data per akun.
class CsvDictionaryRepository implements DictionaryRepository {
  const CsvDictionaryRepository({
    this.assetPath = 'assets/data/dict_entries.csv',
    this.runInBackground = true,
  });

  final String assetPath;

  /// true: urai CSV di isolate terpisah agar UI tidak tersendat.
  /// Isi false hanya di tes widget (isolate nyata tidak jalan di fake async).
  final bool runInBackground;

  @override
  Future<List<DictionaryEntry>> loadEntries() async =>
      (await loadIndex()).entries;

  @override
  Future<DictionaryIndex> loadIndex() async {
    final source = await rootBundle.loadString(assetPath);
    if (!runInBackground) return buildDictionaryIndex(source);
    return compute(buildDictionaryIndex, source);
  }
}

/// Top-level agar bisa dijalankan oleh `compute` di isolate lain.
DictionaryIndex buildDictionaryIndex(String csvSource) =>
    DictionaryIndex.build(CsvDictionaryParser.parse(csvSource));
