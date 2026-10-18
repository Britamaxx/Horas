import 'package:belajar_bahasa_batak/data/dictionary_cache.dart';
import 'package:belajar_bahasa_batak/data/dictionary_index.dart';
import 'package:belajar_bahasa_batak/data/dictionary_pack.dart';
import 'package:belajar_bahasa_batak/data/dictionary_repository.dart';
import 'package:belajar_bahasa_batak/data/dictionary_source.dart';
import 'package:belajar_bahasa_batak/data/synced_dictionary_repository.dart';
import 'package:belajar_bahasa_batak/models/dictionary_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DictionaryPack _pack(int version, List<String> words) => DictionaryPack(
  version: version,
  entries: [
    for (var i = 0; i < words.length; i++)
      {'id': '${i + 1}', 'h': words[i], 'd': 'arti ${words[i]}', 'p': 'NOUN'},
  ],
);

class _FakeSource implements DictionarySource {
  _FakeSource({this.pack, this.error});

  final DictionaryPack? pack;
  final Object? error;
  final calls = <int?>[];

  @override
  Future<DictionaryPack?> fetchLatest({int? ifNewerThan}) async {
    calls.add(ifNewerThan);
    if (error != null) throw error!;
    return pack;
  }
}

class _FakeCache implements DictionaryCache {
  _FakeCache({this.cached});

  final CachedDictionary? cached;
  final saved = <DictionaryPack>[];

  @override
  Future<CachedDictionary?> load() async => cached;

  @override
  Future<void> save(DictionaryPack pack) async => saved.add(pack);

  @override
  Future<DictionaryIndex> saveAndBuildIndex(DictionaryPack pack) async {
    saved.add(pack);
    return DictionaryIndex.build(pack.toEntries());
  }
}

class _FakeFallback implements DictionaryRepository {
  int loads = 0;

  @override
  Future<List<DictionaryEntry>> loadEntries() async =>
      (await loadIndex()).entries;

  @override
  Future<DictionaryIndex> loadIndex() async {
    loads++;
    return DictionaryIndex.build(_pack(0, ['bawaan']).toEntries());
  }
}

CachedDictionary _cached(int version, List<String> words) => CachedDictionary(
  version: version,
  index: DictionaryIndex.build(_pack(version, words).toEntries()),
);

SyncedDictionaryRepository _repository({
  required DictionarySource? source,
  required DictionaryCache? cache,
  required DictionaryRepository fallback,
}) => SyncedDictionaryRepository(
  source: Future<DictionarySource?>.value(source),
  cache: cache,
  fallback: fallback,
);

void main() {
  test('salinan lokal dipakai langsung, versi baru disimpan untuk berikutnya', () async {
    final cache = _FakeCache(cached: _cached(5, ['lama']));
    final source = _FakeSource(pack: _pack(6, ['baru']));
    final fallback = _FakeFallback();

    final index = await _repository(
      source: source,
      cache: cache,
      fallback: fallback,
    ).loadIndex();

    expect(index.entries.single.headword, 'lama');
    await pumpEventQueue();
    expect(source.calls, [5]);
    expect(cache.saved.single.version, 6);
    expect(fallback.loads, 0);
  });

  test('salinan sudah terbaru: tidak ada yang disimpan ulang', () async {
    final cache = _FakeCache(cached: _cached(5, ['lama']));
    final source = _FakeSource(); // null = tidak ada versi lebih baru

    await _repository(
      source: source,
      cache: cache,
      fallback: _FakeFallback(),
    ).loadIndex();

    await pumpEventQueue();
    expect(source.calls, [5]);
    expect(cache.saved, isEmpty);
  });

  test('pertama kali: unduh dari Firebase lalu simpan', () async {
    final cache = _FakeCache();
    final source = _FakeSource(pack: _pack(7, ['satu', 'dua']));
    final fallback = _FakeFallback();

    final index = await _repository(
      source: source,
      cache: cache,
      fallback: fallback,
    ).loadIndex();

    expect(index.entries.map((entry) => entry.headword), ['satu', 'dua']);
    expect(cache.saved.single.version, 7);
    expect(source.calls, [null]);
    expect(fallback.loads, 0);
  });

  test('unduhan gagal: memakai kamus bawaan', () async {
    final cache = _FakeCache();
    final fallback = _FakeFallback();

    final index = await _repository(
      source: _FakeSource(error: StateError('offline')),
      cache: cache,
      fallback: fallback,
    ).loadIndex();

    expect(index.entries.single.headword, 'bawaan');
    expect(cache.saved, isEmpty);
    expect(fallback.loads, 1);
  });

  test('Firebase belum aktif atau kamus belum dipublikasikan: kamus bawaan', () async {
    final fallback = _FakeFallback();
    await _repository(
      source: null,
      cache: _FakeCache(),
      fallback: fallback,
    ).loadIndex();
    expect(fallback.loads, 1);

    final fallback2 = _FakeFallback();
    final cache2 = _FakeCache();
    await _repository(
      source: _FakeSource(), // fetchLatest -> null
      cache: cache2,
      fallback: fallback2,
    ).loadIndex();
    expect(fallback2.loads, 1);
    expect(cache2.saved, isEmpty);
  });

  test('paket kosong ditolak dan tidak disimpan', () async {
    final cache = _FakeCache();
    final fallback = _FakeFallback();

    await _repository(
      source: _FakeSource(pack: const DictionaryPack(version: 9, entries: [])),
      cache: cache,
      fallback: fallback,
    ).loadIndex();

    expect(cache.saved, isEmpty);
    expect(fallback.loads, 1);
  });

  test('decodePackEntries melewati entri tidak lengkap dan memangkas spasi', () {
    final entries = decodePackEntries([
      {'id': '1', 'h': ' nan ', 'd': 'lih. nae', 'p': 'NOUN', 'c': 'reference', 's': 'bbc'},
      {'id': '2', 'h': '', 'd': 'tanpa kata'},
      {'id': '3', 'h': 'tanpa arti'},
      'bukan map',
    ]);
    expect(entries, hasLength(1));
    expect(entries.single.headword, 'nan');
    expect(entries.single.semanticCategories, 'reference');
    expect(entries.single.sourceDialect, 'bbc');
  });
}
