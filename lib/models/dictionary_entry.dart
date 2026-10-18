class DictionaryEntry {
  const DictionaryEntry({
    required this.id,
    required this.headword,
    required this.definitions,
    required this.partOfSpeech,
    required this.semanticCategories,
    required this.sourceDialect,
  });

  final String id;
  final String headword;
  final String definitions;
  final String partOfSpeech;
  final String semanticCategories;
  final String sourceDialect;

  List<String> get definitionOptions {
    final markers = RegExp(r'(?:^|;\s*)\d+\.\s*')
        .allMatches(definitions)
        .toList();
    if (markers.length < 2 || markers.first.start != 0) {
      return [definitions.trim()];
    }

    final options = <String>[];
    for (var index = 0; index < markers.length; index++) {
      final start = markers[index].end;
      final end = index + 1 < markers.length
          ? markers[index + 1].start
          : definitions.length;
      final option = definitions
          .substring(start, end)
          .trim()
          .replaceFirst(RegExp(r';\s*$'), '');
      if (option.isNotEmpty) options.add(option);
    }
    return List.unmodifiable(options);
  }

  String get partOfSpeechLabel => switch (partOfSpeech.toUpperCase()) {
    'NOUN' => 'Kata benda',
    'VERB' => 'Kata kerja',
    'ADJ' => 'Kata sifat',
    'ADV' => 'Kata keterangan',
    'PRON' => 'Kata ganti',
    'ADP' => 'Preposisi',
    'INTJ' => 'Kata seru',
    'NUM' => 'Kata bilangan',
    'DET' => 'Penentu',
    'SCONJ' => 'Konjungsi subordinatif',
    'CCONJ' => 'Konjungsi koordinatif',
    'CONJ' => 'Konjungsi',
    'AUX' => 'Kata bantu',
    'PART' => 'Partikel',
    _ => 'Lainnya',
  };
}
