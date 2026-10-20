import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/quiz_bank_question.dart';
import 'quiz_cache.dart';
import 'quiz_source.dart';

abstract interface class QuizRepository {
  /// Daftar soal. Kosong berarti tidak ada bank soal; aplikasi lalu memakai
  /// soal otomatis dari kamus.
  Future<List<QuizBankQuestion>> loadQuestions();
}

/// Tanpa bank soal (default di tes): kuis memakai soal otomatis dari kamus.
class NoQuizRepository implements QuizRepository {
  const NoQuizRepository();

  @override
  Future<List<QuizBankQuestion>> loadQuestions() async => const [];
}

/// Bank soal dari Firebase dengan salinan lokal:
///
/// 1. Ada salinan di perangkat -> dipakai langsung, lalu di latar belakang
///    dicek versi baru (1 baca). Versi baru dipakai pada pembukaan berikutnya.
/// 2. Belum ada salinan -> diunduh dari Firebase (batas waktu singkat agar
///    pembukaan pertama tidak tertahan).
/// 3. Gagal -> daftar kosong, dan aplikasi memakai soal otomatis dari kamus.
class SyncedQuizRepository implements QuizRepository {
  SyncedQuizRepository({
    required Future<QuizSource?> source,
    required QuizCache cache,
    this.downloadTimeout = const Duration(seconds: 10),
  }) : _source = source,
       _cache = cache;

  final Future<QuizSource?> _source;
  final QuizCache _cache;
  final Duration downloadTimeout;

  @override
  Future<List<QuizBankQuestion>> loadQuestions() async {
    try {
      final cached = await _cache.load();
      if (cached != null && cached.questions.isNotEmpty) {
        unawaited(_refreshInBackground(cached.version));
        return cached.questions;
      }
    } catch (error) {
      debugPrint('Salinan soal kuis tidak bisa dibaca: $error');
    }

    try {
      final source = await _source;
      if (source != null) {
        final pack = await source.fetchLatest().timeout(downloadTimeout);
        if (pack != null && pack.questions.isNotEmpty) {
          try {
            await _cache.save(pack);
          } catch (error) {
            debugPrint('Soal kuis tidak bisa disimpan di perangkat: $error');
          }
          return pack.questions;
        }
      }
    } catch (error) {
      debugPrint('Soal kuis Firebase tidak bisa dimuat, memakai soal kamus: $error');
    }
    return const [];
  }

  Future<void> _refreshInBackground(int cachedVersion) async {
    try {
      final source = await _source;
      if (source == null) return;
      final pack = await source.fetchLatest(ifNewerThan: cachedVersion);
      if (pack == null || pack.questions.isEmpty) return;
      await _cache.save(pack);
    } catch (error) {
      debugPrint('Pembaruan soal kuis ditunda: $error');
    }
  }
}
