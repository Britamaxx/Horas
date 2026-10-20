import 'dart:math';

import 'package:belajar_bahasa_batak/data/csv_dictionary_parser.dart';
import 'package:belajar_bahasa_batak/data/dictionary_index.dart';
import 'package:belajar_bahasa_batak/models/quiz_bank_question.dart';
import 'package:belajar_bahasa_batak/services/quiz_builder.dart';
import 'package:flutter_test/flutter_test.dart';

const _csv = '''id,headword,definitions,partOfSpeech,semanticCategories,sourceDialect,deletedAt
1,abu,ragon,NOUN,,bbc,
2,acak,galumang,VERB,,bbc,
3,aduh,ai,INTJ,,bbc,
4,api,apui,NOUN,,bbc,
''';

List<QuizBankQuestion> _bank(int count) => [
  for (var i = 0; i < count; i++)
    QuizBankQuestion(
      id: 'q$i',
      word: 'kata$i',
      answer: 'arti$i',
      wrong: ['salah${i}a', 'salah${i}b', 'salah${i}c'],
    ),
];

void main() {
  final index = DictionaryIndex.build(CsvDictionaryParser.parse(_csv));

  test('bank soal dipakai: 10 soal tanpa pengulangan, jawaban ada di pilihan', () {
    final items = buildQuizItems(index: index, bank: _bank(25));

    expect(items, hasLength(10));
    expect(items.map((item) => item.word).toSet(), hasLength(10));
    for (final item in items) {
      expect(item.word, startsWith('kata'));
      expect(item.options, hasLength(4));
      expect(item.options, contains(item.correctDefinition));
      expect(item.options.toSet(), hasLength(4));
      expect(item.partOfSpeechLabel, isNull);
    }
  });

  test('bank lebih kecil dari jumlah soal: semua dipakai', () {
    expect(buildQuizItems(index: index, bank: _bank(3)), hasLength(3));
  });

  test('bank berisi soal: soal kamus tidak ikut dipakai', () {
    final words = buildQuizItems(
      index: index,
      bank: _bank(5),
    ).map((item) => item.word).toSet();
    expect(words, everyElement(startsWith('kata')));
    expect(words.intersection({'abu', 'acak', 'aduh', 'api'}), isEmpty);
  });

  test('bank kosong: soal dibuat otomatis dari kamus', () {
    final items = buildQuizItems(index: index);

    expect(items, hasLength(4));
    for (final item in items) {
      expect(['abu', 'acak', 'aduh', 'api'], contains(item.word));
      expect(item.options, hasLength(4));
      expect(item.options, contains(item.correctDefinition));
      expect(item.partOfSpeechLabel, isNotNull);
    }
  });

  test('bank kosong dan kamus kosong: tidak ada soal', () {
    final empty = DictionaryIndex.build(const []);
    expect(buildQuizItems(index: empty), isEmpty);
  });

  test('hasil sama jika Random diberi seed yang sama', () {
    List<String> words(int seed) => buildQuizItems(
      index: index,
      bank: _bank(25),
      random: Random(seed),
    ).map((item) => item.word).toList();

    expect(words(7), words(7));
  });
}
