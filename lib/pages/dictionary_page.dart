part of '../main.dart';

class _DictionaryScreen extends StatefulWidget {
  const _DictionaryScreen({
    super.key,
    required this.controller,
    required this.initialQuery,
  });

  final AppController controller;
  final String initialQuery;

  @override
  State<_DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<_DictionaryScreen> {
  late final TextEditingController _searchController;
  String _query = '';
  String _partOfSpeech = 'ALL';
  int _visibleLimit = 60;
  Timer? _searchDebounce;
  late List<DictionaryEntry> _results;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _searchController = TextEditingController(text: _query);
    _results = _runSearch();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Pencarian hanya dijalankan saat kata kunci/filter berubah, bukan setiap
  // build, sehingga menyimpan kata atau berpindah tab tidak menyaring ulang.
  List<DictionaryEntry> _runSearch() =>
      widget.controller.index.search(_query, partOfSpeech: _partOfSpeech);

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _visibleLimit = 60;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _results = _runSearch());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final normalizedQuery = _query.trim();
    final results = _results;
    final shownCount = min(results.length, _visibleLimit);
    final dictionaryIndex = widget.controller.index;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kamus Batak', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Cari dalam kata Indonesia atau padanan Batak.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Contoh: abang',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              _searchDebounce?.cancel();
                              setState(() {
                                _query = '';
                                _visibleLimit = 60;
                                _results = _runSearch();
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _partOfSpeech,
                  decoration: const InputDecoration(
                    labelText: 'Kelas kata',
                    prefixIcon: Icon(Icons.tune_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'ALL',
                      child: Text('Semua kelas kata'),
                    ),
                    ...dictionaryIndex.partsOfSpeech.map(
                      (part) => DropdownMenuItem(
                        value: part,
                        child: Text(dictionaryIndex.partLabels[part] ?? part),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _partOfSpeech = value ?? 'ALL';
                    _visibleLimit = 60;
                    _results = _runSearch();
                  }),
                ),
                const SizedBox(height: 14),
                Text(
                  normalizedQuery.isEmpty && _partOfSpeech == 'ALL'
                      ? '${results.length} entri kamus'
                      : '${results.length} hasil',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: results.isEmpty
                      ? _EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Kata belum ditemukan',
                          message:
                              'Coba kata lain atau pilih semua kelas kata.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24, top: 4),
                          itemCount:
                              shownCount +
                              (results.length > shownCount ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, indent: 48),
                          itemBuilder: (context, index) {
                            if (index == shownCount) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _visibleLimit += 60),
                                  child: Text(
                                    'Tampilkan ${min(60, results.length - shownCount)} kata lagi',
                                  ),
                                ),
                              );
                            }
                            final entry = results[index];
                            return _DictionaryEntryTile(
                              entry: entry,
                              saved: widget.controller.isSaved(entry),
                              onOpen: () => _showEntryDetails(
                                context,
                                entry,
                                widget.controller,
                              ),
                              onToggleSaved: () =>
                                  widget.controller.toggleSaved(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DictionaryEntryTile extends StatelessWidget {
  const _DictionaryEntryTile({
    required this.entry,
    required this.saved,
    required this.onOpen,
    required this.onToggleSaved,
  });

  final DictionaryEntry entry;
  final bool saved;
  final VoidCallback onOpen;
  final Future<void> Function() onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  saved ? Icons.bookmark_rounded : Icons.menu_book_outlined,
                  color: saved ? scheme.secondary : scheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.headword, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      entry.definitions,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.partOfSpeechLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: saved ? 'Hapus dari kata tersimpan' : 'Simpan kata',
                onPressed: () => _performSavedAction(context, onToggleSaved),
                icon: Icon(
                  saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                  color: saved ? scheme.secondary : scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showEntryDetails(
  BuildContext context,
  DictionaryEntry entry,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.headword,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry.partOfSpeechLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(entry.definitions, style: theme.textTheme.bodyLarge),
              if (entry.semanticCategories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Kategori: ${entry.semanticCategories}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (entry.sourceDialect.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Dialek sumber: ${entry.sourceDialect}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await controller.toggleSaved(entry);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kata tidak dapat disimpan: $error'),
                      ),
                    );
                    return;
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                icon: Icon(
                  controller.isSaved(entry)
                      ? Icons.bookmark_remove_outlined
                      : Icons.bookmark_add_outlined,
                ),
                label: Text(
                  controller.isSaved(entry)
                      ? 'Hapus dari kata tersimpan'
                      : 'Simpan kata',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _performSavedAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kata tidak dapat disimpan: $error')),
    );
  }
}

