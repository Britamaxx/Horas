import 'package:cloud_firestore/cloud_firestore.dart';

import 'quiz_pack.dart';
import 'quiz_source.dart';

/// Tata letak di Firestore (dibuat oleh `tools/publish_quiz.py`):
///
///   quiz_meta/current            { version, packCount, questionCount }
///   quiz_packs/{version}_{000..} { version, index, questions: [ {id, word, answer, wrong} ] }
///
/// Satu pemasangan baru cukup membaca packCount + 1 dokumen (sekitar 2).
class FirestoreQuizSource implements QuizSource {
  FirestoreQuizSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const metaCollection = 'quiz_meta';
  static const metaDocument = 'current';
  static const packCollection = 'quiz_packs';

  final FirebaseFirestore _firestore;

  static String packId(int version, int index) =>
      '${version}_${index.toString().padLeft(3, '0')}';

  @override
  Future<QuizPack?> fetchLatest({int? ifNewerThan}) async {
    final metaSnapshot = await _firestore
        .collection(metaCollection)
        .doc(metaDocument)
        .get();
    final meta = metaSnapshot.data();
    if (meta == null) return null; // belum ada soal yang dipublikasikan

    final version = _asInt(meta['version']);
    final packCount = _asInt(meta['packCount']);
    final questionCount = _asInt(meta['questionCount']);
    if (version == null || packCount == null || packCount <= 0) {
      throw const FormatException('Metadata soal kuis di Firestore tidak valid.');
    }
    if (ifNewerThan != null && version <= ifNewerThan) return null;

    final snapshots = await Future.wait([
      for (var i = 0; i < packCount; i++)
        _firestore.collection(packCollection).doc(packId(version, i)).get(),
    ]);

    final raw = <Object?>[];
    for (var i = 0; i < snapshots.length; i++) {
      final data = snapshots[i].data();
      if (data == null || _asInt(data['version']) != version) {
        throw StateError(
          'Paket soal ${i + 1}/$packCount belum lengkap '
          '(mungkin sedang diperbarui). Coba lagi nanti.',
        );
      }
      final list = data['questions'];
      if (list is! List) {
        throw StateError('Paket soal ${i + 1} tidak berisi daftar soal.');
      }
      raw.addAll(list);
    }
    if (questionCount != null && raw.length != questionCount) {
      throw StateError(
        'Jumlah soal tidak cocok (diterima ${raw.length}, seharusnya $questionCount).',
      );
    }

    final questions = parseQuizQuestions(raw);
    if (questions.isEmpty) throw StateError('Bank soal kuis kosong.');
    return QuizPack(version: version, questions: questions);
  }

  static int? _asInt(Object? value) => value is num ? value.toInt() : null;
}
