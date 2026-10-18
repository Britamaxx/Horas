import 'package:belajar_bahasa_batak/services/learning_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tamu memakai kunci lama; akun punya cache terpisah', () async {
    SharedPreferences.setMockInitialValues({
      'saved_dictionary_entry_ids': ['1'],
      'completed_quizzes': 2,
    });
    const guest = LearningProgressStore();
    final account = LearningProgressStore.forUser('u1');

    expect(await guest.loadSavedEntryIds(), {'1'});
    expect((await guest.loadQuizStats()).completedQuizzes, 2);
    expect(await account.loadSavedEntryIds(), isEmpty);
    expect((await account.loadQuizStats()).isEmpty, isTrue);

    await account.saveEntryIds({'9'});
    await account.saveQuizStats(
      const QuizStats(
        completedQuizzes: 1,
        correctAnswers: 3,
        answeredQuestions: 5,
      ),
    );
    expect(await guest.loadSavedEntryIds(), {'1'});
    expect((await account.loadQuizStats()).correctAnswers, 3);
    expect(
      await LearningProgressStore.forUser('u2').loadSavedEntryIds(),
      isEmpty,
    );
  });

  test('clear hanya mengosongkan penyimpanan yang dipilih', () async {
    SharedPreferences.setMockInitialValues({
      'saved_dictionary_entry_ids': ['1'],
      'completed_quizzes': 2,
    });
    const guest = LearningProgressStore();
    final account = LearningProgressStore.forUser('u1');
    await account.saveEntryIds({'9'});

    await guest.clear();

    expect(await guest.loadSavedEntryIds(), isEmpty);
    expect((await guest.loadQuizStats()).isEmpty, isTrue);
    expect(await account.loadSavedEntryIds(), {'9'});
  });

  test('QuizStats dapat dijumlahkan', () {
    const a = QuizStats(
      completedQuizzes: 1,
      correctAnswers: 4,
      answeredQuestions: 5,
    );
    const b = QuizStats(
      completedQuizzes: 2,
      correctAnswers: 6,
      answeredQuestions: 10,
    );
    final sum = a + b;
    expect(sum.completedQuizzes, 3);
    expect(sum.correctAnswers, 10);
    expect(sum.answeredQuestions, 15);
  });
}
