// Android/iOS/desktop memakai berkas lokal; web tidak punya cache berkas.
export 'dictionary_cache_stub.dart'
    if (dart.library.io) 'dictionary_cache_io.dart'
    show createDictionaryCache;
