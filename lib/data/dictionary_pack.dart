import '../models/dictionary_entry.dart';

/// Satu versi kamus yang diunduh dari Firestore: kumpulan entri ringkas.
/// Kunci: id, h (kata), d (arti), p (kelas kata), c (kategori), s (dialek).
class DictionaryPack {
  const DictionaryPack({required this.version, required this.entries});

  final int version;
  final List<Map<String, Object?>> entries;

  List<DictionaryEntry> toEntries() => decodePackEntries(entries);
}

/// Mengubah entri ringkas menjadi [DictionaryEntry]. Entri tanpa id, kata,
/// atau arti dilewati (sama seperti aturan pada CSV).
List<DictionaryEntry> decodePackEntries(Iterable<Object?> raw) {
  final result = <DictionaryEntry>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final id = _text(item, 'id');
    final headword = _text(item, 'h');
    final definitions = _text(item, 'd');
    if (id.isEmpty || headword.isEmpty || definitions.isEmpty) continue;
    result.add(
      DictionaryEntry(
        id: id,
        headword: headword,
        definitions: definitions,
        partOfSpeech: _text(item, 'p'),
        semanticCategories: _text(item, 'c'),
        sourceDialect: _text(item, 's'),
      ),
    );
  }
  return result;
}

String _text(Map<Object?, Object?> item, String key) =>
    (item[key] ?? '').toString().trim();
