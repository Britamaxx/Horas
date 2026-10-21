part of '../main.dart';

class _AppShell extends StatefulWidget {
  const _AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;
  String _dictionaryQuery = '';
  int _dictionaryEpoch = 0;
  int _practiceEpoch = 0;

  void _openDictionary([String query = '']) {
    setState(() {
      _selectedIndex = 1;
      _dictionaryQuery = query;
      _dictionaryEpoch++;
    });
  }

  void _openPractice() {
    setState(() {
      _selectedIndex = 2;
      _practiceEpoch++;
    });
  }

  List<Widget> get _pages => [
    _HomeScreen(
      controller: widget.controller,
      onOpenDictionary: _openDictionary,
      onOpenPractice: _openPractice,
    ),
    _DictionaryScreen(
      key: ValueKey(_dictionaryEpoch),
      controller: widget.controller,
      initialQuery: _dictionaryQuery,
    ),
    _PracticeScreen(
      key: ValueKey(_practiceEpoch),
      controller: widget.controller,
    ),
    _ProfileScreen(
      controller: widget.controller,
      onOpenDictionary: _openDictionary,
    ),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Beranda',
    ),
    NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Kamus'),
    NavigationDestination(
      icon: Icon(Icons.edit_note_rounded),
      selectedIcon: Icon(Icons.edit_note_rounded),
      label: 'Latihan',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (index) {
                          setState(() => _selectedIndex = index);
                        },
                        labelType: constraints.maxWidth >= 900
                            ? NavigationRailLabelType.all
                            : NavigationRailLabelType.selected,
                        destinations: _destinations
                            .map(
                              (destination) => NavigationRailDestination(
                                icon: destination.icon,
                                selectedIcon: destination.selectedIcon,
                                label: Text(destination.label),
                              ),
                            )
                            .toList(),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: _pages,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
              body: IndexedStack(index: _selectedIndex, children: _pages),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                destinations: _destinations,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeScreen extends StatefulWidget {
  const _HomeScreen({
    required this.controller,
    required this.onOpenDictionary,
    required this.onOpenPractice,
  });

  final AppController controller;
  final ValueChanged<String> onOpenDictionary;
  final VoidCallback onOpenPractice;

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    widget.onOpenDictionary(_searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final savedEntries = widget.controller.savedEntries(limit: 3);
    final quizStats = widget.controller.quizStats;
    final hasStudied =
        quizStats.completedQuizzes > 0 || savedEntries.isNotEmpty;
    final reviewEntry = savedEntries.isEmpty ? null : savedEntries.first;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final practicePanel = _TodayPracticePanel(
            title: reviewEntry == null
                ? quizStats.completedQuizzes > 0
                      ? 'Kuis kosakata berikutnya'
                      : 'Kuis kosakata'
                : 'Kata tersimpanmu',
            description: reviewEntry == null
                ? quizStats.completedQuizzes > 0
                      ? '${quizStats.completedQuizzes} kuis selesai · ${quizStats.answeredQuestions} soal dijawab.'
                      : 'Pilih padanan Batak untuk kata-kata dari kamus.'
                : 'Kata tersimpan pilihanmu: “${reviewEntry.headword}” dan lainnya.',
            actionLabel: reviewEntry == null ? 'Mulai kuis' : 'Buka kata',
            onStart: reviewEntry == null
                ? widget.onOpenPractice
                : () => widget.onOpenDictionary(reviewEntry.headword),
          );

          final quickActions = Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.search_rounded,
                  label: 'Jelajahi kamus',
                  onTap: () => widget.onOpenDictionary(''),
                ),
              ),
            ],
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 20,
                  isWide ? 28 : 20,
                  isWide ? 32 : 20,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const HorasLogo.mark(size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Horas',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 24,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${_formatCount(widget.controller.entries.length)} entri',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isWide ? 24 : 18),
                    _TobaWordSlider(onOpenDictionary: widget.onOpenDictionary),
                    SizedBox(height: isWide ? 48 : 36),
                    Text(
                      hasStudied
                          ? 'Senang belajar lagi?'
                          : 'Mulai dari satu kata.',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: isWide ? 44 : 34,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        hasStudied
                            ? 'Kata pilihan dan latihanmu tersimpan di perangkat ini.'
                            : 'Cari arti kata, simpan pilihanmu, lalu latih ingatan lewat kuis.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              children: [
                                _buildSearchField(),
                                const SizedBox(height: 20),
                                practicePanel,
                                const SizedBox(height: 16),
                                quickActions,
                              ],
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            flex: 5,
                            child: _buildSavedWordsSection(
                              context,
                              savedEntries,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildSearchField(),
                      const SizedBox(height: 22),
                      practicePanel,
                      const SizedBox(height: 16),
                      quickActions,
                      const SizedBox(height: 30),
                      _buildSavedWordsSection(context, savedEntries),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _search(),
      decoration: InputDecoration(
        hintText: 'Cari kata Indonesia atau Batak',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'Cari di kamus',
          onPressed: _search,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
    );
  }

  Widget _buildSavedWordsSection(
    BuildContext context,
    List<DictionaryEntry> savedEntries,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                savedEntries.isEmpty ? 'Mulai dari kamus' : 'Kata pilihanmu',
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (savedEntries.isNotEmpty)
              TextButton(
                onPressed: () => widget.onOpenDictionary(''),
                child: const Text('Semua'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          savedEntries.isEmpty
              ? 'Simpan kata yang ingin kamu ingat; kata itu akan muncul di sini.'
              : 'Lanjutkan dari kosakata yang sudah kamu simpan.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (savedEntries.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bookmark_add_outlined, color: scheme.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Belum ada kata tersimpan',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih ikon penanda di kamus untuk menyimpan kata.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => widget.onOpenDictionary(''),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Buka kamus'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...savedEntries.map(
            (entry) => _DictionaryEntryTile(
              entry: entry,
              saved: widget.controller.isSaved(entry),
              onOpen: () =>
                  _showEntryDetails(context, entry, widget.controller),
              onToggleSaved: () => widget.controller.toggleSaved(entry),
            ),
          ),
      ],
    );
  }
}


/// Pita tiga garis ala ulos (merah, hitam, emas) sebagai penanda merek.
/// Garis tenun tipis di tepi atas panel.
