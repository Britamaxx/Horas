import 'package:belajar_bahasa_batak/data/csv_dictionary_parser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CsvDictionaryParser', () {
    test('parses quoted commas, escaped quotes, and embedded newlines', () {
      const source =
          '\uFEFFid,headword,definitions,deletedAt,partOfSpeech,'
          'semanticCategories,sourceDialect\r\n'
          '1,"kata, contoh","arti ""khusus""\ndan lanjut",,NOUN,cat,bbc\r\n'
          '2,terhapus,arti,2025-01-01,VERB,,\r\n';

      final entries = CsvDictionaryParser.parse(source);

      expect(entries, hasLength(1));
      expect(entries.single.headword, 'kata, contoh');
      expect(entries.single.definitions, 'arti "khusus"\ndan lanjut');
      expect(entries.single.sourceDialect, 'bbc');
      expect(entries.single.partOfSpeechLabel, 'Kata benda');
    });

    test('rejects an unterminated quoted field', () {
      const source =
          'id,headword,definitions,partOfSpeech\n1,kata,"arti belum selesai,NOUN';

      expect(() => CsvDictionaryParser.parse(source), throwsFormatException);
    });

    test(
      'splits numbered dictionary senses into separate practice choices',
      () {
        const source =
            'id,headword,definitions,deletedAt,partOfSpeech\n'
            '1,abang,"1. angkang; 2. abang dari ibu: tulang",,NOUN';

        final entry = CsvDictionaryParser.parse(source).single;

        expect(entry.definitionOptions, ['angkang', 'abang dari ibu: tulang']);
      },
    );
  });

  test('loads all active entries from the bundled CSV asset', () async {
    final source = await rootBundle.loadString('assets/data/dict_entries.csv');

    final entries = CsvDictionaryParser.parse(source);

    expect(entries, hasLength(14618));
    expect(entries.first.headword, 'abad');
    expect(entries.first.definitions, 'abat');
  });
}
