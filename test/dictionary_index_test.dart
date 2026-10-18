import 'package:belajar_bahasa_batak/data/csv_dictionary_parser.dart';
import 'package:belajar_bahasa_batak/data/dictionary_index.dart';
import 'package:flutter_test/flutter_test.dart';

const _csv = '''id,headword,definitions,partOfSpeech,semanticCategories,sourceDialect,deletedAt
1,abang,"1. angkang; 2. abang dari ibu: tulang",NOUN,kinship,bbc,
2,abu,ragon,NOUN,,bbc,
3,acak,galumang,VERB,,bbc,
4,Aduh,ai,INTJ,,bbc,
''';

void main() {
  late DictionaryIndex index;

  setUp(() {
    index = DictionaryIndex.build(CsvDictionaryParser.parse(_csv));
  });

  List<String> ids(List<dynamic> entries) =>
      entries.map((entry) => entry.id as String).toList();

  group('search', () {
    test('tanpa kata kunci dan filter mengembalikan semua entri', () {
      expect(ids(index.search('')), ['1', '2', '3', '4']);
    });

    test('mencocokkan kata', () {
      expect(ids(index.search('ab')), ['1', '2']);
    });

    test('mencocokkan arti', () {
      expect(ids(index.search('ragon')), ['2']);
    });

    test('tidak membedakan huruf besar/kecil dan mengabaikan spasi tepi', () {
      expect(ids(index.search('ADUH')), ['4']);
      expect(ids(index.search('  abu ')), ['2']);
    });

    test('filter kelas kata', () {
      expect(ids(index.search('', partOfSpeech: 'VERB')), ['3']);
      expect(ids(index.search('ab', partOfSpeech: 'NOUN')), ['1', '2']);
      expect(index.search('ab', partOfSpeech: 'VERB'), isEmpty);
    });
  });

  test('kelas kata terurut dan punya label', () {
    expect(index.partsOfSpeech, ['INTJ', 'NOUN', 'VERB']);
    expect(index.partLabels['NOUN'], 'Kata benda');
  });

  test('entriesForIds mengikuti urutan kamus dan melewati id asing', () {
    expect(ids(index.entriesForIds({'3', '1', '999'})), ['1', '3']);
    expect(ids(index.entriesForIds({'3', '1', '4'}, limit: 2)), ['1', '3']);
  });

  test('bahan kuis hanya dari entri berarti tunggal', () {
    expect(index.quizSeeds.map((seed) => seed.entry.id), ['2', '3', '4']);
    expect(index.distractorPool.toSet(), {
      'angkang',
      'abang dari ibu: tulang',
      'ragon',
      'galumang',
      'ai',
    });
  });
}
