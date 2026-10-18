import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'dictionary_cache.dart';
import 'dictionary_index.dart';
import 'dictionary_pack.dart';

DictionaryCache? createDictionaryCache() => const IoDictionaryCache();

/// Menyimpan kamus sebagai satu berkas JSON di folder data aplikasi.
/// Membaca, menulis, dan membangun indeks dikerjakan di isolate terpisah.
class IoDictionaryCache implements DictionaryCache {
  const IoDictionaryCache();

  static const _fileName = 'dictionary_cache_v1.json';

  Future<String> _path() async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}${Platform.pathSeparator}$_fileName';
  }

  @override
  Future<CachedDictionary?> load() async {
    final path = await _path();
    if (!await File(path).exists()) return null;
    try {
      return await compute(_readCache, path);
    } catch (error) {
      debugPrint('Cache kamus rusak, diabaikan: $error');
      return null;
    }
  }

  @override
  Future<void> save(DictionaryPack pack) async {
    await compute(_writeCache, _WriteRequest(await _path(), pack));
  }

  @override
  Future<DictionaryIndex> saveAndBuildIndex(DictionaryPack pack) async {
    return compute(_writeCacheAndBuild, _WriteRequest(await _path(), pack));
  }
}

class _WriteRequest {
  const _WriteRequest(this.path, this.pack);

  final String path;
  final DictionaryPack pack;
}

CachedDictionary? _readCache(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) return null;
  final version = decoded['version'];
  final raw = decoded['entries'];
  if (version is! int || raw is! List) return null;
  final entries = decodePackEntries(raw);
  if (entries.isEmpty) return null;
  return CachedDictionary(
    version: version,
    index: DictionaryIndex.build(entries),
  );
}

void _writeCache(_WriteRequest request) {
  // Tulis ke berkas sementara lalu ganti nama: cache lama tidak rusak jika
  // aplikasi tertutup di tengah penulisan.
  final temp = File('${request.path}.tmp');
  temp.writeAsStringSync(
    jsonEncode({'version': request.pack.version, 'entries': request.pack.entries}),
  );
  temp.renameSync(request.path);
}

DictionaryIndex _writeCacheAndBuild(_WriteRequest request) {
  _writeCache(request);
  return DictionaryIndex.build(request.pack.toEntries());
}
