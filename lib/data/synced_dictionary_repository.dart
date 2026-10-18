import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/dictionary_entry.dart';
import 'dictionary_cache.dart';
import 'dictionary_index.dart';
import 'dictionary_pack.dart';
import 'dictionary_repository.dart';
import 'dictionary_source.dart';

/// Kamus dari Firebase dengan salinan lokal:
///
/// 1. Ada salinan di perangkat -> dipakai langsung (instan, bisa offline), lalu
///    di latar belakang dicek apakah ada versi lebih baru di Firebase. Versi
///    baru disimpan dan mulai dipakai pada pembukaan aplikasi berikutnya.
/// 2. Belum ada salinan (pertama kali) -> diunduh dari Firebase.
/// 3. Gagal (offline saat pertama kali, Firebase belum aktif, kamus belum
///    dipublikasikan) -> memakai kamus bawaan [fallback] agar aplikasi tetap jalan.
class SyncedDictionaryRepository implements DictionaryRepository {
  SyncedDictionaryRepository({
    required Future<DictionarySource?> source,
    required DictionaryCache? cache,
    required DictionaryRepository fallback,
    this.downloadTimeout = const Duration(seconds: 30),
  }) : _source = source,
       _cache = cache,
       _fallback = fallback;

  final Future<DictionarySource?> _source;
  final DictionaryCache? _cache;
  final DictionaryRepository _fallback;
  final Duration downloadTimeout;

  @override
  Future<List<DictionaryEntry>> loadEntries() async =>
      (await loadIndex()).entries;

  @override
  Future<DictionaryIndex> loadIndex() async {
    final cache = _cache;
    if (cache != null) {
      CachedDictionary? cached;
      try {
        cached = await cache.load();
      } catch (error) {
        debugPrint('Salinan kamus tidak bisa dibaca: $error');
      }
      if (cached != null) {
        unawaited(_refreshInBackground(cache, cached.version));
        return cached.index;
      }
    }

    try {
      final source = await _source;
      if (source != null) {
        final pack = await source.fetchLatest().timeout(downloadTimeout);
        if (pack != null) {
          if (pack.entries.isEmpty) throw StateError('Paket kamus kosong.');
          return cache != null
              ? await cache.saveAndBuildIndex(pack)
              : await compute(buildIndexFromPack, pack);
        }
      }
    } catch (error) {
      debugPrint('Kamus Firebase tidak bisa dimuat, memakai kamus bawaan: $error');
    }
    return _fallback.loadIndex();
  }

  Future<void> _refreshInBackground(
    DictionaryCache cache,
    int cachedVersion,
  ) async {
    try {
      final source = await _source;
      if (source == null) return;
      final pack = await source.fetchLatest(ifNewerThan: cachedVersion);
      if (pack == null || pack.entries.isEmpty) return;
      await cache.save(pack);
    } catch (error) {
      debugPrint('Pembaruan kamus ditunda: $error');
    }
  }
}

/// Top-level agar bisa dijalankan oleh `compute`.
DictionaryIndex buildIndexFromPack(DictionaryPack pack) =>
    DictionaryIndex.build(pack.toEntries());
