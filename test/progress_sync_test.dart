import 'dart:async';

import 'package:belajar_bahasa_batak/data/auth_repository.dart';
import 'package:belajar_bahasa_batak/data/csv_dictionary_parser.dart';
import 'package:belajar_bahasa_batak/data/dictionary_index.dart';
import 'package:belajar_bahasa_batak/data/progress_repository.dart';
import 'package:belajar_bahasa_batak/main.dart';
import 'package:belajar_bahasa_batak/models/app_user.dart';
import 'package:belajar_bahasa_batak/services/learning_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _csv = '''id,headword,definitions,partOfSpeech,semanticCategories,sourceDialect,deletedAt
1,abang,angkang,NOUN,,bbc,
2,abu,ragon,NOUN,,bbc,
3,acak,galumang,VERB,,bbc,
''';

class _FakeAuth implements AuthRepository {
  final changes = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> get authStateChanges => changes.stream;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

class _FakeProgress implements ProgressRepository {
  final cloud = StreamController<ProgressSnapshot>.broadcast();
  final calls = <String>[];

  @override
  Stream<ProgressSnapshot> watchProgress(String uid) => cloud.stream;

  @override
  Future<void> setEntrySaved(
    String uid,
    String entryId, {
    required bool saved,
  }) async {
    calls.add('save:$uid:$entryId:$saved');
  }

  @override
  Future<void> recordQuiz(String uid, int correct, int total) async {
    calls.add('quiz:$uid:$correct/$total');
  }

  @override
  Future<void> mergeGuestProgress(String uid, ProgressSnapshot guest) async {
    final ids = guest.savedEntryIds.toList()..sort();
    calls.add('merge:$uid:${ids.join(',')}:${guest.quizStats.completedQuizzes}');
  }
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 400 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'kondisi tidak terpenuhi tepat waktu');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('progres tamu pindah ke akun, lalu tersinkron dan terpisah per akun', () async {
    SharedPreferences.setMockInitialValues({
      'saved_dictionary_entry_ids': ['2'],
      'completed_quizzes': 1,
      'correct_answers': 4,
      'answered_questions': 5,
    });
    final index = DictionaryIndex.build(CsvDictionaryParser.parse(_csv));
    final auth = _FakeAuth();
    final progress = _FakeProgress();
    final controller = AppController(
      index: index,
      savedEntryIds: {'2'},
      quizStats: const QuizStats(
        completedQuizzes: 1,
        correctAnswers: 4,
        answeredQuestions: 5,
      ),
      authRepository: auth,
      userProfileRepository: null,
      progressStore: const LearningProgressStore(),
      progressRepository: progress,
    );
    addTearDown(() async {
      controller.dispose();
      await auth.changes.close();
      await progress.cloud.close();
    });

    // Login: data tamu dipindah ke akun dan dikirim ke cloud.
    auth.changes.add(const AppUser(uid: 'u1'));
    await _until(() => progress.cloud.hasListener);
    expect(progress.calls, ['merge:u1:2:1']);
    expect(controller.savedEntryIds, {'2'});
    expect(await const LearningProgressStore().loadSavedEntryIds(), isEmpty);
    expect(
      await LearningProgressStore.forUser('u1').loadSavedEntryIds(),
      {'2'},
    );

    // Menyimpan kata: UI langsung berubah, cloud menerima operasi atomik.
    await controller.toggleSaved(index.entries.first);
    expect(controller.savedEntryIds, {'1', '2'});
    expect(progress.calls.last, 'save:u1:1:true');
    await controller.toggleSaved(index.entries.first);
    expect(controller.savedEntryIds, {'2'});
    expect(progress.calls.last, 'save:u1:1:false');

    // Kuis tercatat dan dikirim.
    await controller.recordQuiz(3, 5);
    expect(controller.quizStats.completedQuizzes, 2);
    expect(progress.calls.last, 'quiz:u1:3/5');

    // Perubahan dari perangkat lain menggantikan keadaan lokal.
    progress.cloud.add(
      const ProgressSnapshot(
        savedEntryIds: {'3'},
        quizStats: QuizStats(completedQuizzes: 7),
      ),
    );
    await _until(() => controller.savedEntryIds.contains('3'));
    expect(controller.savedEntryIds, {'3'});
    expect(controller.quizStats.completedQuizzes, 7);

    // Keluar: kembali ke mode tamu yang kosong, data akun tidak terlihat.
    auth.changes.add(null);
    await _until(() => controller.savedEntryIds.isEmpty);
    expect(controller.quizStats.isEmpty, isTrue);

    // Akun lain di perangkat yang sama tidak melihat progres u1.
    auth.changes.add(const AppUser(uid: 'u2'));
    await _until(() => progress.cloud.hasListener);
    expect(controller.savedEntryIds, isEmpty);
  });
}
