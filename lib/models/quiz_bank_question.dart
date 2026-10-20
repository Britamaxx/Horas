/// Satu soal dari bank soal kuis di Firestore (quiz_packs).
class QuizBankQuestion {
  const QuizBankQuestion({
    required this.id,
    required this.word,
    required this.answer,
    required this.wrong,
  });

  final String id;

  /// Kata bahasa Batak yang ditanyakan.
  final String word;

  /// Jawaban benar (bahasa Indonesia).
  final String answer;

  /// Pilihan yang salah.
  final List<String> wrong;

  /// Membaca satu soal dari data mentah. Mengembalikan null jika tidak valid
  /// (kosong, tanpa pilihan salah, atau pilihan salah sama dengan jawaban),
  /// sehingga satu soal rusak tidak merusak seluruh bank soal.
  static QuizBankQuestion? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = _text(raw['id']);
    final word = _text(raw['word']);
    final answer = _text(raw['answer']);
    final rawWrong = raw['wrong'];
    if (id.isEmpty || word.isEmpty || answer.isEmpty || rawWrong is! List) {
      return null;
    }
    final seen = <String>{answer.toLowerCase()};
    final wrong = <String>[];
    for (final item in rawWrong) {
      final option = _text(item);
      if (option.isEmpty) continue;
      if (seen.add(option.toLowerCase())) wrong.add(option);
    }
    if (wrong.isEmpty) return null;
    return QuizBankQuestion(
      id: id,
      word: word,
      answer: answer,
      wrong: List.unmodifiable(wrong),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'word': word,
    'answer': answer,
    'wrong': wrong,
  };

  static String _text(Object? value) => (value ?? '').toString().trim();
}
