import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'quiz_pack.dart';

/// Salinan bank soal di perangkat supaya Latihan siap instan dan bisa offline.
abstract interface class QuizCache {
  /// Null jika belum ada salinan atau salinannya rusak.
  Future<QuizPack?> load();

  Future<void> save(QuizPack pack);
}

/// Bank soal hanya belasan KB, jadi cukup disimpan di SharedPreferences
/// (berbeda dengan kamus yang besar dan memakai berkas).
class PrefsQuizCache implements QuizCache {
  const PrefsQuizCache();

  static const _key = 'quiz_bank_cache_v1';

  @override
  Future<QuizPack?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final version = decoded['version'];
      final list = decoded['questions'];
      if (version is! int || list is! List) return null;
      final questions = parseQuizQuestions(list);
      if (questions.isEmpty) return null;
      return QuizPack(version: version, questions: questions);
    } catch (_) {
      return null; // salinan rusak: abaikan, nanti diunduh ulang
    }
  }

  @override
  Future<void> save(QuizPack pack) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode({
        'version': pack.version,
        'questions': [for (final q in pack.questions) q.toJson()],
      }),
    );
  }
}
