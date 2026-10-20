import '../models/quiz_bank_question.dart';

/// Satu versi bank soal kuis.
class QuizPack {
  const QuizPack({required this.version, required this.questions});

  final int version;
  final List<QuizBankQuestion> questions;
}

/// Mengubah data mentah menjadi soal; yang tidak valid dilewati.
List<QuizBankQuestion> parseQuizQuestions(Iterable<Object?> raw) {
  final seenIds = <String>{};
  final result = <QuizBankQuestion>[];
  for (final item in raw) {
    final question = QuizBankQuestion.tryParse(item);
    if (question != null && seenIds.add(question.id)) result.add(question);
  }
  return result;
}
