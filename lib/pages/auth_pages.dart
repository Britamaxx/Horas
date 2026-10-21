part of '../main.dart';

/// sesi tamu). Pemilik [AppController], jadi dialah yang membuangnya.
class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.controller});

  final AppController controller;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppController>.value(
      value: widget.controller,
      child: Consumer<AppController>(
        builder: (context, controller, _) {
          final Widget child;
          if (!controller.authResolved) {
            child = const Scaffold(
              key: ValueKey('auth-loading'),
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (controller.currentUser != null ||
              controller.isGuestSession) {
            child = _AppShell(
              key: const ValueKey('app-shell'),
              controller: controller,
            );
          } else {
            child = _WelcomeScreen(
              key: const ValueKey('welcome'),
              controller: controller,
            );
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: child,
          );
        },
      ),
    );
  }
}

class _WelcomeScreen extends StatefulWidget {
  const _WelcomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<_WelcomeScreen> {
  bool _isSigningIn = false;
  String? _message;
  String? _messageDetail;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _message = null;
      _messageDetail = null;
    });
    try {
      await widget.controller.signInWithGoogle();
      // Beri waktu event status login tiba; kalau berhasil, gerbang akan
      // otomatis memindahkan pengguna ke beranda dan layar ini dilepas.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      if (widget.controller.currentUser == null) {
        setState(() {
          _message =
              'Login dibatalkan. Coba lagi, atau lanjutkan sebagai tamu.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message =
            'Login Google gagal. Periksa koneksi internet lalu coba lagi.';
        _messageDetail = '$error';
      });
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _continueAsGuest() => widget.controller.continueAsGuest();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final authConfigured = widget.controller.authRepository != null;

    return Scaffold(
      body: ColoredBox(
        color: scheme.surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 18 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: HorasLogo.full(width: 220)),
                      const SizedBox(height: 12),
                      Text(
                        'Selamat datang!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Cari arti kata, simpan pilihanmu, lalu latih '
                        'ingatan lewat kuis Bahasa Batak Toba.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton(
                        onPressed: authConfigured && !_isSigningIn
                            ? _signInWithGoogle
                            : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: scheme.surface,
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(color: scheme.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSigningIn)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              SvgPicture.string(
                                _googleLogoSvg,
                                width: 20,
                                height: 20,
                              ),
                            const SizedBox(width: 12),
                            const Text('Login with Google'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSigningIn ? null : _continueAsGuest,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.person_outline_rounded),
                        label: const Text('Continue as Guest'),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _message!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                              if (_messageDetail != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _messageDetail!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onErrorContainer,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: _isSigningIn
                                    ? null
                                    : _signInWithGoogle,
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.onErrorContainer,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 36),
                                ),
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        authConfigured
                            ? 'Sebagai tamu, progresmu tersimpan di perangkat '
                                  'ini. Masuk dengan Google untuk menyimpannya '
                                  'di akunmu.'
                            : 'Login Google belum tersedia di versi ini. Kamu '
                                  'tetap bisa belajar sebagai tamu.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

