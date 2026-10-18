import 'package:shared_preferences/shared_preferences.dart';

class QuizStats {
  const QuizStats({
    this.completedQuizzes = 0,
    this.correctAnswers = 0,
    this.answeredQuestions = 0,
  });

  final int completedQuizzes;
  final int correctAnswers;
  final int answeredQuestions;

  double get accuracy =>
      answeredQuestions == 0 ? 0 : correctAnswers / answeredQuestions;

  bool get isEmpty =>
      completedQuizzes == 0 && correctAnswers == 0 && answeredQuestions == 0;

  QuizStats recordQuiz(int correct, int total) => QuizStats(
    completedQuizzes: completedQuizzes + 1,
    correctAnswers: correctAnswers + correct,
    answeredQuestions: answeredQuestions + total,
  );

  QuizStats operator +(QuizStats other) => QuizStats(
    completedQuizzes: completedQuizzes + other.completedQuizzes,
    correctAnswers: correctAnswers + other.correctAnswers,
    answeredQuestions: answeredQuestions + other.answeredQuestions,
  );
}

/// Progres satu akun (atau satu perangkat tamu): kata tersimpan + statistik kuis.
class ProgressSnapshot {
  const ProgressSnapshot({
    this.savedEntryIds = const <String>{},
    this.quizStats = const QuizStats(),
  });

  final Set<String> savedEntryIds;
  final QuizStats quizStats;
}

/// Cache lokal progres di perangkat (SharedPreferences).
///
/// `const LearningProgressStore()` = penyimpanan TAMU dan memakai kunci lama,
/// sehingga data pengguna yang sudah ada tidak hilang.
/// `LearningProgressStore.forUser(uid)` = cache terpisah per akun, supaya dua
/// akun di satu perangkat tidak saling melihat atau menimpa progres.
class LearningProgressStore {
  const LearningProgressStore() : _prefix = '';

  LearningProgressStore.forUser(String uid) : _prefix = 'acct.$uid.';

  final String _prefix;

  String get _savedEntriesKey => '${_prefix}saved_dictionary_entry_ids';
  String get _completedQuizzesKey => '${_prefix}completed_quizzes';
  String get _correctAnswersKey => '${_prefix}correct_answers';
  String get _answeredQuestionsKey => '${_prefix}answered_questions';

  Future<Set<String>> loadSavedEntryIds() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_savedEntriesKey) ?? const <String>[])
        .toSet();
  }

  Future<QuizStats> loadQuizStats() async {
    final preferences = await SharedPreferences.getInstance();
    return QuizStats(
      completedQuizzes: preferences.getInt(_completedQuizzesKey) ?? 0,
      correctAnswers: preferences.getInt(_correctAnswersKey) ?? 0,
      answeredQuestions: preferences.getInt(_answeredQuestionsKey) ?? 0,
    );
  }

  Future<void> saveEntryIds(Set<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_savedEntriesKey, ids.toList()..sort());
  }

  /// Menimpa statistik dengan nilai mutlak (dipakai saat menerima data cloud).
  Future<void> saveQuizStats(QuizStats stats) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_completedQuizzesKey, stats.completedQuizzes);
    await preferences.setInt(_correctAnswersKey, stats.correctAnswers);
    await preferences.setInt(_answeredQuestionsKey, stats.answeredQuestions);
  }

  Future<void> recordQuiz(int correct, int total) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _completedQuizzesKey,
      (preferences.getInt(_completedQuizzesKey) ?? 0) + 1,
    );
    await preferences.setInt(
      _correctAnswersKey,
      (preferences.getInt(_correctAnswersKey) ?? 0) + correct,
    );
    await preferences.setInt(
      _answeredQuestionsKey,
      (preferences.getInt(_answeredQuestionsKey) ?? 0) + total,
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_savedEntriesKey);
    await preferences.remove(_completedQuizzesKey);
    await preferences.remove(_correctAnswersKey);
    await preferences.remove(_answeredQuestionsKey);
  }
}
