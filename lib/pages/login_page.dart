part of '../main.dart';

class _LoginScreen extends StatefulWidget {
  const _LoginScreen({required this.controller});

  final AppController controller;

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  bool _isSigningIn = false;
  String? _signInError;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _signInError = null;
    });
    try {
      await widget.controller.signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _signInError = 'Login Google gagal: $error');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final authConfigured = widget.controller.authRepository != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Masuk ke Horas')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: HorasLogo.mark(size: 64),
                ),
                const SizedBox(height: 20),
                Text(
                  'Satu akun untuk progresmu.',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk dengan Google agar profil dan kemajuan belajar '
                  'dapat disiapkan untuk sinkronisasi Firebase.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: authConfigured && !_isSigningIn
                      ? _signInWithGoogle
                      : null,
                  icon: _isSigningIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_circle_outlined),
                  label: const Text('Lanjutkan dengan Google'),
                ),
                if (_signInError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _signInError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    authConfigured
                        ? 'Firebase Authentication sudah tersedia. '
                              'Profil pengguna akan tersimpan melalui '
                              'repository akun.'
                        : 'Login belum aktif. Firebase project, konfigurasi '
                              'FlutterFire, dan penyedia Google perlu disiapkan '
                              'terlebih dahulu. Tidak ada data login yang '
                              'dikirim dari layar ini.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cloudflare Turnstile bersifat opsional untuk verifikasi '
                  'anti-bot melalui endpoint server; rahasia Turnstile tidak '
                  'boleh ditanam di aplikasi.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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

