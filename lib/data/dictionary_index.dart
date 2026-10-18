import 'dart:math';

import '../models/dictionary_entry.dart';

/// Bahan satu soal kuis: kata + satu-satunya artinya.
class QuizSeed {
  const QuizSeed(this.entry, this.definition);

  final DictionaryEntry entry;
  final String definition;
}

/// Semua hal yang berat dihitung SEKALI saat kamus dimuat (di isolate latar
/// belakang), sehingga pencarian, kuis, dan daftar kata tersimpan di UI hanya
/// perlu operasi ringan.
class DictionaryIndex {
  DictionaryIndex._({
    required this.entries,
    required List<String> searchKeys,
    required List<String> partKeys,
    required Map<String, int> positionById,
    required this.partsOfSpeech,
    required this.partLabels,
    required this.quizSeeds,
    required this.distractorPool,
  }) : _searchKeys = searchKeys,
       _partKeys = partKeys,
       _positionById = positionById;

  factory DictionaryIndex.build(List<DictionaryEntry> entries) {
    final searchKeys = List<String>.generate(
      entries.length,
      // \u0000 memisahkan kata dan arti: kueri biasa tidak mungkin memuatnya,
      // jadi cocok di sini sama dengan cocok di kata ATAU di arti.
      (i) => '${entries[i].headword}\u0000${entries[i].definitions}'
          .toLowerCase(),
      growable: false,
    );
    final partKeys = List<String>.generate(
      entries.length,
      (i) => entries[i].partOfSpeech.toUpperCase(),
      growable: false,
    );
    final positionById = <String, int>{
      for (var i = 0; i < entries.length; i++) entries[i].id: i,
    };

    final partLabels = <String, String>{};
    for (var i = 0; i < entries.length; i++) {
      final part = partKeys[i];
      if (part.isEmpty) continue;
      partLabels.putIfAbsent(part, () => entries[i].partOfSpeechLabel);
    }
    final partsOfSpeech = partLabels.keys.toList()..sort();

    final definitionPool = <String>{};
    final quizSeeds = <QuizSeed>[];
    for (final entry in entries) {
      final options = entry.definitionOptions;
      for (final option in options) {
        if (option.isNotEmpty) definitionPool.add(option);
      }
      if (options.length == 1 &&
          entry.headword.isNotEmpty &&
          entry.definitions.isNotEmpty) {
        quizSeeds.add(QuizSeed(entry, options.single));
      }
    }

    return DictionaryIndex._(
      entries: List.unmodifiable(entries),
      searchKeys: searchKeys,
      partKeys: partKeys,
      positionById: positionById,
      partsOfSpeech: List.unmodifiable(partsOfSpeech),
      partLabels: Map.unmodifiable(partLabels),
      quizSeeds: List.unmodifiable(quizSeeds),
      distractorPool: List.unmodifiable(definitionPool),
    );
  }

  final List<DictionaryEntry> entries;
  final List<String> _searchKeys;
  final List<String> _partKeys;
  final Map<String, int> _positionById;

  /// Kelas kata yang ada (huruf besar, terurut) dan label Indonesianya.
  final List<String> partsOfSpeech;
  final Map<String, String> partLabels;

  /// Kandidat soal kuis dan kumpulan arti unik untuk pilihan pengecoh.
  final List<QuizSeed> quizSeeds;
  final List<String> distractorPool;

  /// Mencari [query] di kata atau arti (tanpa membedakan huruf besar/kecil),
  /// opsional dibatasi pada satu kelas kata (huruf besar, mis. 'NOUN').
  /// Tidak membuat string baru per entri, jadi aman dipanggil saat mengetik.
  List<DictionaryEntry> search(String query, {String partOfSpeech = 'ALL'}) {
    final needle = query.trim().toLowerCase();
    final anyPart = partOfSpeech == 'ALL';
    if (needle.isEmpty && anyPart) return entries;

    final results = <DictionaryEntry>[];
    for (var i = 0; i < entries.length; i++) {
      if (!anyPart && _partKeys[i] != partOfSpeech) continue;
      if (needle.isNotEmpty && !_searchKeys[i].contains(needle)) continue;
      results.add(entries[i]);
    }
    return results;
  }

  /// Entri untuk [ids] dalam urutan kamus; id yang tidak dikenal dilewati.
  List<DictionaryEntry> entriesForIds(Iterable<String> ids, {int? limit}) {
    final positions = <int>[];
    for (final id in ids) {
      final position = _positionById[id];
      if (position != null) positions.add(position);
    }
    positions.sort();
    final end = limit == null ? positions.length : min(limit, positions.length);
    return [for (var i = 0; i < end; i++) entries[positions[i]]];
  }
}
