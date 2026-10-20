import 'package:belajar_bahasa_batak/data/quiz_cache.dart';
import 'package:belajar_bahasa_batak/data/quiz_pack.dart';
import 'package:belajar_bahasa_batak/data/quiz_repository.dart';
import 'package:belajar_bahasa_batak/data/quiz_source.dart';
import 'package:belajar_bahasa_batak/models/quiz_bank_question.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuizBankQuestion _q(String word) => QuizBankQuestion(
  id: 'id-$word',
  word: word,
  answer: 'arti $word',
  wrong: const ['a', 'b', 'c'],
);

QuizPack _pack(int version, List<String> words) =>
    QuizPack(version: version, questions: [for (final w in words) _q(w)]);

class _FakeSource implements QuizSource {
  _FakeSource({this.pack, this.error});

  final QuizPack? pack;
  final Object? error;
  final calls = <int?>[];

  @override
  Future<QuizPack?> fetchLatest({int? ifNewerThan}) async {
    calls.add(ifNewerThan);
    if (error != null) throw error!;
    return pack;
  }
}

class _FakeCache implements QuizCache {
  _FakeCache({this.cached, this.failOnSave = false});

  final QuizPack? cached;
  final bool failOnSave;
  final saved = <QuizPack>[];

  @override
  Future<QuizPack?> load() async => cached;

  @override
  Future<void> save(QuizPack pack) async {
    if (failOnSave) throw StateError('penyimpanan penuh');
    saved.add(pack);
  }
}

SyncedQuizRepository _repository(QuizSource? source, QuizCache cache) =>
    SyncedQuizRepository(source: Future<QuizSource?>.value(source), cache: cache);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncedQuizRepository', () {
    test('salinan lokal dipakai langsung, versi baru disimpan untuk berikutnya', () async {
      final cache = _FakeCache(cached: _pack(5, ['lama']));
      final source = _FakeSource(pack: _pack(6, ['baru']));

      final questions = await _repository(source, cache).loadQuestions();

      expect(questions.single.word, 'lama');
      await pumpEventQueue();
      expect(source.calls, [5]);
      expect(cache.saved.single.version, 6);
    });

    test('salinan sudah terbaru: tidak disimpan ulang', () async {
      final cache = _FakeCache(cached: _pack(5, ['lama']));
      final source = _FakeSource(); // null = tidak ada versi lebih baru

      await _repository(source, cache).loadQuestions();

      await pumpEventQueue();
      expect(source.calls, [5]);
      expect(cache.saved, isEmpty);
    });

    test('pertama kali: unduh lalu simpan', () async {
      final cache = _FakeCache();
      final source = _FakeSource(pack: _pack(7, ['satu', 'dua']));

      final questions = await _repository(source, cache).loadQuestions();

      expect(questions.map((q) => q.word), ['satu', 'dua']);
      expect(cache.saved.single.version, 7);
      expect(source.calls, [null]);
    });

    test('gagal menyimpan salinan tidak membuang soal yang sudah diunduh', () async {
      final questions = await _repository(
        _FakeSource(pack: _pack(7, ['satu'])),
        _FakeCache(failOnSave: true),
      ).loadQuestions();

      expect(questions.single.word, 'satu');
    });

    test('unduhan gagal, Firebase belum aktif, atau belum dipublikasikan: kosong', () async {
      expect(
        await _repository(
          _FakeSource(error: StateError('offline')),
          _FakeCache(),
        ).loadQuestions(),
        isEmpty,
      );
      expect(await _repository(null, _FakeCache()).loadQuestions(), isEmpty);
      expect(
        await _repository(_FakeSource(), _FakeCache()).loadQuestions(),
        isEmpty,
      );
    });
  });

  test('NoQuizRepository selalu kosong', () async {
    expect(await const NoQuizRepository().loadQuestions(), isEmpty);
  });

  group('QuizBankQuestion.tryParse', () {
    test('soal valid dibaca dan dirapikan', () {
      final q = QuizBankQuestion.tryParse({
        'id': ' a1 ',
        'word': ' mangan ',
        'answer': 'makan',
        'wrong': [' malam ', 'garam', 'mandi'],
      });
      expect(q, isNotNull);
      expect(q!.id, 'a1');
      expect(q.word, 'mangan');
      expect(q.wrong, ['malam', 'garam', 'mandi']);
    });

    test('pilihan salah yang sama dengan jawaban atau kembar dibuang', () {
      final q = QuizBankQuestion.tryParse({
        'id': 'a',
        'word': 'w',
        'answer': 'Makan',
        'wrong': ['makan', 'garam', 'GARAM', ''],
      });
      expect(q!.wrong, ['garam']);
    });

    test('soal tidak valid menghasilkan null', () {
      expect(QuizBankQuestion.tryParse('bukan map'), isNull);
      expect(QuizBankQuestion.tryParse({'id': 'a', 'word': 'w', 'answer': 'x'}), isNull);
      expect(
        QuizBankQuestion.tryParse({'id': 'a', 'word': '', 'answer': 'x', 'wrong': ['y']}),
        isNull,
      );
      expect(
        QuizBankQuestion.tryParse({'id': 'a', 'word': 'w', 'answer': 'x', 'wrong': ['x']}),
        isNull,
      );
    });

    test('parseQuizQuestions melewati soal rusak dan id ganda', () {
      final valid = {'id': 'a', 'word': 'w', 'answer': 'x', 'wrong': ['y']};
      final parsed = parseQuizQuestions([valid, valid, 'rusak', {'id': 'b'}]);
      expect(parsed.map((q) => q.id), ['a']);
    });
  });

  group('PrefsQuizCache', () {
    test('simpan lalu muat kembali', () async {
      SharedPreferences.setMockInitialValues({});
      const cache = PrefsQuizCache();
      expect(await cache.load(), isNull);

      await cache.save(_pack(9, ['satu', 'dua']));
      final loaded = await cache.load();

      expect(loaded!.version, 9);
      expect(loaded.questions.map((q) => q.word), ['satu', 'dua']);
      expect(loaded.questions.first.wrong, ['a', 'b', 'c']);
    });

    test('salinan rusak diabaikan', () async {
      SharedPreferences.setMockInitialValues({'quiz_bank_cache_v1': '{bukan json'});
      expect(await const PrefsQuizCache().load(), isNull);

      SharedPreferences.setMockInitialValues({
        'quiz_bank_cache_v1': '{"version": 1, "questions": []}',
      });
      expect(await const PrefsQuizCache().load(), isNull);
    });
  });
}
