import '../models/dictionary_entry.dart';

class CsvDictionaryParser {
  const CsvDictionaryParser._();

  static List<DictionaryEntry> parse(String source) {
    final rows = _parseRows(source);
    if (rows.isEmpty) {
      throw const FormatException('File kamus tidak memiliki baris header.');
    }

    final headers = rows.first
        .map((header) => header.replaceFirst('\uFEFF', '').trim())
        .toList();
    final requiredColumns = ['id', 'headword', 'definitions', 'partOfSpeech'];
    final missingColumns = requiredColumns
        .where((column) => !headers.contains(column))
        .toList();
    if (missingColumns.isNotEmpty) {
      throw FormatException(
        'Kolom wajib tidak ditemukan: ${missingColumns.join(', ')}.',
      );
    }

    final columnIndexes = {
      for (var index = 0; index < headers.length; index++)
        headers[index]: index,
    };

    String valueAt(List<String> row, String column) {
      final index = columnIndexes[column];
      if (index == null || index >= row.length) return '';
      return row[index].trim();
    }

    final entries = <DictionaryEntry>[];
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.every((value) => value.trim().isEmpty)) continue;
      if (valueAt(row, 'deletedAt').isNotEmpty) continue;

      final id = valueAt(row, 'id');
      final headword = valueAt(row, 'headword');
      final definitions = valueAt(row, 'definitions');
      if (id.isEmpty || headword.isEmpty || definitions.isEmpty) {
        throw FormatException(
          'Entri kamus pada baris ${rowIndex + 1} kehilangan id, kata, atau arti.',
        );
      }

      entries.add(
        DictionaryEntry(
          id: id,
          headword: headword,
          definitions: definitions,
          partOfSpeech: valueAt(row, 'partOfSpeech'),
          semanticCategories: valueAt(row, 'semanticCategories'),
          sourceDialect: valueAt(row, 'sourceDialect'),
        ),
      );
    }

    if (entries.isEmpty) {
      throw const FormatException('Tidak ada entri kamus yang bisa digunakan.');
    }
    return List.unmodifiable(entries);
  }

  static List<List<String>> _parseRows(String source) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var insideQuotedField = false;

    void finishField() {
      row.add(field.toString());
      field.clear();
    }

    void finishRow() {
      finishField();
      rows.add(row);
      row = <String>[];
    }

    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (insideQuotedField) {
        if (character == '"') {
          if (index + 1 < source.length && source[index + 1] == '"') {
            field.write('"');
            index++;
          } else {
            insideQuotedField = false;
          }
        } else {
          field.write(character);
        }
        continue;
      }

      if (character == '"' && field.isEmpty) {
        insideQuotedField = true;
      } else if (character == ',') {
        finishField();
      } else if (character == '\r' || character == '\n') {
        finishRow();
        if (character == '\r' &&
            index + 1 < source.length &&
            source[index + 1] == '\n') {
          index++;
        }
      } else {
        field.write(character);
      }
    }

    if (insideQuotedField) {
      throw const FormatException('File CSV berakhir di dalam tanda kutip.');
    }
    if (field.isNotEmpty || row.isNotEmpty) finishRow();
    return rows;
  }
}
