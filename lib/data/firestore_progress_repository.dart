import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/learning_progress_store.dart';
import 'progress_repository.dart';

/// Progres satu akun disimpan di SATU dokumen: `users/{uid}/progress/summary`.
///
/// Satu dokumen = membuka aplikasi cuma 1 baca (bukan 1 baca per kata
/// tersimpan), dan tiap perubahan 1 tulis. Perubahan memakai operasi atomik
/// (arrayUnion/arrayRemove/increment) sehingga dua perangkat yang mengubah
/// progres bersamaan saling tergabung, bukan saling menimpa.
class FirestoreProgressRepository implements ProgressRepository {
  FirestoreProgressRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('progress')
      .doc('summary');

  @override
  Stream<ProgressSnapshot> watchProgress(String uid) {
    return _doc(uid)
        .snapshots(includeMetadataChanges: true)
        // Lewati keadaan sementara yang masih memuat tulisan lokal belum
        // terkirim: UI sudah memperbaruinya sendiri (optimistis).
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        // Dokumen belum ada di cache & belum dikonfirmasi server = belum tahu.
        .where((snapshot) => snapshot.exists || !snapshot.metadata.isFromCache)
        .map(_toProgress);
  }

  @override
  Future<void> setEntrySaved(
    String uid,
    String entryId, {
    required bool saved,
  }) {
    return _doc(uid).set({
      'savedEntryIds': saved
          ? FieldValue.arrayUnion([entryId])
          : FieldValue.arrayRemove([entryId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> recordQuiz(String uid, int correct, int total) {
    return _doc(uid).set({
      'completedQuizzes': FieldValue.increment(1),
      'correctAnswers': FieldValue.increment(correct),
      'answeredQuestions': FieldValue.increment(total),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> mergeGuestProgress(String uid, ProgressSnapshot guest) {
    final stats = guest.quizStats;
    final data = <String, Object?>{'updatedAt': FieldValue.serverTimestamp()};
    if (guest.savedEntryIds.isNotEmpty) {
      data['savedEntryIds'] = FieldValue.arrayUnion(
        guest.savedEntryIds.toList(),
      );
    }
    if (!stats.isEmpty) {
      data['completedQuizzes'] = FieldValue.increment(stats.completedQuizzes);
      data['correctAnswers'] = FieldValue.increment(stats.correctAnswers);
      data['answeredQuestions'] = FieldValue.increment(stats.answeredQuestions);
    }
    if (data.length == 1) return Future<void>.value();
    return _doc(uid).set(data, SetOptions(merge: true));
  }

  ProgressSnapshot _toProgress(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return const ProgressSnapshot();
    final ids = data['savedEntryIds'];
    return ProgressSnapshot(
      savedEntryIds: ids is List
          ? ids.whereType<String>().toSet()
          : <String>{},
      quizStats: QuizStats(
        completedQuizzes: _asInt(data['completedQuizzes']),
        correctAnswers: _asInt(data['correctAnswers']),
        answeredQuestions: _asInt(data['answeredQuestions']),
      ),
    );
  }

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;
}
