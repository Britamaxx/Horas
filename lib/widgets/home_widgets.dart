part of '../main.dart';

class _UlosStripe extends StatelessWidget {
  const _UlosStripe();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 8,
      child: Row(
        children: [
          Expanded(flex: 6, child: ColoredBox(color: _ulosBlack)),
          Expanded(flex: 1, child: ColoredBox(color: _gold)),
          Expanded(flex: 3, child: ColoredBox(color: _ulosBlack)),
        ],
      ),
    );
  }
}

/// Satu kata Batak Toba di slider beranda. Semua kata ada di kamus bawaan.
class _TobaWord {
  const _TobaWord({
    required this.word,
    required this.label,
    required this.meaning,
    required this.background,
    required this.foreground,
    required this.muted,
    required this.stripes,
  });

  final String word;

  /// Fungsi kata dalam percakapan, mis. "Salam".
  final String label;
  final String meaning;
  final Color background;
  final Color foreground;

  /// Warna teks sekunder: turunan dari latar, bukan abu-abu transparan.
  final Color muted;

  /// Tiga warna pita tenun di tepi atas panel.
  final List<Color> stripes;
}

const _tobaWords = <_TobaWord>[
  _TobaWord(
    word: 'Horas',
    label: 'Salam',
    meaning: 'Sehat, senang, makmur. Sapaan khas orang Batak.',
    background: _ulosRed,
    foreground: Color(0xFFFFF4F1),
    muted: Color(0xFFF2C9C3),
    stripes: [_ulosBlack, _gold, Color(0xFFFFF4F1)],
  ),
  _TobaWord(
    word: 'Mauliate',
    label: 'Terima kasih',
    meaning: 'Ucapan terima kasih. Tambahkan “godang” untuk “banyak”.',
    background: _ulosBlack,
    foreground: Color(0xFFF7E7B6),
    muted: Color(0xFFCDB57A),
    stripes: [_ulosRed, _gold, _ulosRed],
  ),
  _TobaWord(
    word: 'Santabi',
    label: 'Permisi',
    meaning: 'Ucapan hormat: permisi, mohon maaf.',
    background: Color(0xFFE9DFDA),
    foreground: Color(0xFF3A1512),
    muted: Color(0xFF6B3F3A),
    stripes: [_ulosRed, _ulosBlack, _ulosRed],
  ),
  _TobaWord(
    word: 'Olo',
    label: 'Ya',
    meaning: 'Setuju, menurut. Lawannya “dang”, yang berarti tidak.',
    background: _gold,
    foreground: Color(0xFF2B1F00),
    muted: Color(0xFF4A3600),
    stripes: [_ulosBlack, _ulosRed, _ulosBlack],
  ),
];

/// Slider kata Batak Toba yang bergeser otomatis tiap 4,5 detik.
/// Berhenti saat disentuh/di-hover, bisa dijeda, dan tidak berputar sendiri
/// bila pengguna meminta gerakan dikurangi.
class _TobaWordSlider extends StatefulWidget {
  const _TobaWordSlider({required this.onOpenDictionary});

  final ValueChanged<String> onOpenDictionary;

  @override
  State<_TobaWordSlider> createState() => _TobaWordSliderState();
}

class _TobaWordSliderState extends State<_TobaWordSlider>
    with SingleTickerProviderStateMixin {
  static const _interval = Duration(milliseconds: 4500);
  static final _start = _tobaWords.length * 500;

  late final PageController _pages = PageController(initialPage: _start);
  late final AnimationController _progress;
  int _pageIndex = _start;
  bool _playing = _webFonts; // tidak berputar di tes widget
  bool _held = false; // sedang disentuh / di-hover
  bool _motionChecked = false;

  int get _current => _pageIndex % _tobaWords.length;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _interval)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _goTo(_pageIndex + 1);
      });
    if (_playing) _progress.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_motionChecked) {
      _motionChecked = true;
      if (MediaQuery.of(context).disableAnimations) {
        _playing = false;
        _progress.stop();
      }
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (!_pages.hasClients) return;
    if (MediaQuery.of(context).disableAnimations) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _hold(bool value) {
    _held = value;
    if (value) {
      _progress.stop();
    } else if (_playing) {
      _progress.forward();
    }
  }

  void _togglePlaying() {
    setState(() => _playing = !_playing);
    if (_playing && !_held) {
      _progress.forward();
    } else {
      _progress.stop();
    }
  }

  void _onPageChanged(int page) {
    setState(() => _pageIndex = page);
    _progress.reset();
    if (_playing && !_held) _progress.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Semantics(
          container: true,
          label: 'Kata-kata Batak, bergeser otomatis',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MouseRegion(
                onEnter: (_) => _hold(true),
                onExit: (_) => _hold(false),
                child: Listener(
                  onPointerDown: (_) => _hold(true),
                  onPointerUp: (_) => _hold(false),
                  onPointerCancel: (_) => _hold(false),
                  child: SizedBox(
                    height: wide ? 320 : 300,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: PageView.builder(
                          controller: _pages,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, i) {
                            final word = _tobaWords[i % _tobaWords.length];
                            return _TobaWordPane(
                              item: word,
                              wide: wide,
                              onOpen: () => widget.onOpenDictionary(word.word),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _tobaWords.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _goTo(_pageIndex - _current + i),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SegmentBar(
                                progress: _progress,
                                state: i < _current
                                    ? 1
                                    : i == _current
                                    ? -1
                                    : 0,
                                color: scheme.primary,
                                track: scheme.outlineVariant,
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _tobaWords[i].word,
                                  maxLines: 1,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: i == _current
                                        ? scheme.onSurface
                                        : scheme.onSurfaceVariant,
                                    fontWeight: i == _current
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: _playing ? 'Jeda geseran' : 'Putar geseran',
                    onPressed: _togglePlaying,
                    icon: Icon(
                      _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Batang waktu: terisi penuh (state 1), sedang berjalan (-1), atau kosong (0).
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.progress,
    required this.state,
    required this.color,
    required this.track,
  });

  final Animation<double> progress;
  final int state;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final fill = state == 1 ? 1.0 : (state == 0 ? 0.0 : progress.value);
        return SizedBox(
          height: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: track),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: state == -1 && fill == 0 ? 0.0 : fill,
                  child: ColoredBox(color: color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TobaWordPane extends StatelessWidget {
  const _TobaWordPane({
    required this.item,
    required this.wide,
    required this.onOpen,
  });

  final _TobaWord item;
  final bool wide;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = item.foreground;
    final pad = wide ? 32.0 : 22.0;
    return ColoredBox(
      color: item.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pita tenun di tepi atas, senada dengan panel latihan.
          SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(flex: 6, child: ColoredBox(color: item.stripes[0])),
                Expanded(flex: 1, child: ColoredBox(color: item.stripes[1])),
                Expanded(flex: 3, child: ColoredBox(color: item.stripes[2])),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, pad - 6, pad, pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(color: item.muted),
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.word,
                      maxLines: 1,
                      style: _display(
                        TextStyle(
                          fontSize: wide ? 104 : 72,
                          height: 0.95,
                          letterSpacing: wide ? -3 : -2,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      item.meaning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: item.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: fg,
                      foregroundColor: item.background,
                    ),
                    onPressed: onOpen,
                    child: const Text('Lihat di kamus'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayPracticePanel extends StatelessWidget {
  const _TodayPracticePanel({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onStart,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: _ulosRed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _UlosStripe(),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFF6DEDA),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _paper,
                      foregroundColor: _ink,
                    ),
                    onPressed: onStart,
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

