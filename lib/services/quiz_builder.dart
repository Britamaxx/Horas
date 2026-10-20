import 'dart:math';

import '../data/dictionary_index.dart';
import '../models/quiz_bank_question.dart';

/// Satu soal siap tampil di layar Latihan.
class QuizItem {
  const QuizItem({
    required this.word,
    required this.correctDefinition,
    required this.options,
    this.partOfSpeechLabel,
  });

  /// Kata bahasa Batak yang ditanyakan.
  final String word;

  /// Jawaban benar (salah satu isi [options]).
  final String correctDefinition;
  final List<String> options;

  /// Kelas kata; null untuk soal dari bank soal (tidak ada datanya).
  final String? partOfSpeechLabel;
}

/// Menyusun satu putaran kuis.
///
/// Jika [bank] berisi soal (dari Firestore), HANYA soal itu yang dipakai.
/// Jika kosong, soal dibuat otomatis dari kamus ([index]).
List<QuizItem> buildQuizItems({
  required DictionaryIndex index,
  List<QuizBankQuestion> bank = const [],
  int count = 10,
  Random? random,
}) {
  final rng = random ?? Random();
  return bank.isNotEmpty
      ? _fromBank(bank, count, rng)
      : _fromDictionary(index, count, rng);
}

List<QuizItem> _fromBank(List<QuizBankQuestion> bank, int count, Random rng) {
  final picked = List<QuizBankQuestion>.of(bank)..shuffle(rng);
  return [
    for (final question in picked.take(count))
      QuizItem(
        word: question.word,
        correctDefinition: question.answer,
        options: List.unmodifiable(
          <String>[question.answer, ...question.wrong]..shuffle(rng),
        ),
      ),
  ];
}

/// Soal diambil acak dari data yang sudah disiapkan di [DictionaryIndex],
/// jadi tidak perlu memindai seluruh kamus.
List<QuizItem> _fromDictionary(DictionaryIndex index, int count, Random rng) {
  final seeds = index.quizSeeds;
  final pool = index.distractorPool;
  if (seeds.isEmpty || pool.length < 2) return const [];

  final questionCount = min(count, seeds.length);
  final picked = <int>{};
  while (picked.length < questionCount) {
    picked.add(rng.nextInt(seeds.length));
  }

  return [
    for (final seedIndex in picked)
      _dictionaryItem(seeds[seedIndex], pool, rng),
  ];
}

QuizItem _dictionaryItem(QuizSeed seed, List<String> pool, Random rng) {
  final wanted = min(3, pool.length - 1);
  final distractors = <String>{};
  var attempts = 0;
  while (distractors.length < wanted && attempts < 200) {
    attempts++;
    final candidate = pool[rng.nextInt(pool.length)];
    if (candidate != seed.definition) distractors.add(candidate);
  }
  final options = <String>[seed.definition, ...distractors]..shuffle(rng);
  return QuizItem(
    word: seed.entry.headword,
    correctDefinition: seed.definition,
    options: List.unmodifiable(options),
    partOfSpeechLabel: seed.entry.partOfSpeechLabel,
  );
}
