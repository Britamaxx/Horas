class SentenceExercise {
  const SentenceExercise({
    required this.id,
    required this.dialect,
    required this.indonesianPrompt,
    required this.batakSentence,
    required this.tokens,
    required this.sourceName,
    required this.sourceReference,
  });

  final String id;
  final String dialect;
  final String indonesianPrompt;
  final String batakSentence;
  final List<String> tokens;
  final String sourceName;
  final String sourceReference;

  Map<String, Object?> toJson() => {
    'id': id,
    'dialect': dialect,
    'indonesianPrompt': indonesianPrompt,
    'batakSentence': batakSentence,
    'tokens': tokens,
    'sourceName': sourceName,
    'sourceReference': sourceReference,
  };

  factory SentenceExercise.fromJson(Map<String, Object?> json) {
    final tokens = json['tokens'];
    if (tokens is! List ||
        tokens.isEmpty ||
        tokens.any((token) => token is! String || token.trim().isEmpty)) {
      throw const FormatException(
        'Latihan kalimat harus memiliki daftar token berurutan.',
      );
    }

    final batakSentence = _requiredString(json, 'batakSentence');
    final orderedTokens = List<String>.unmodifiable(tokens.cast<String>());
    if (orderedTokens.join(' ') != batakSentence) {
      throw const FormatException(
        'batakSentence harus sama dengan tokens dalam urutan sumber.',
      );
    }

    return SentenceExercise(
      id: _requiredString(json, 'id'),
      dialect: _requiredString(json, 'dialect'),
      indonesianPrompt: _requiredString(json, 'indonesianPrompt'),
      batakSentence: batakSentence,
      tokens: orderedTokens,
      sourceName: _requiredString(json, 'sourceName'),
      sourceReference: _requiredString(json, 'sourceReference'),
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key wajib diisi.');
    }
    return value;
  }
}
