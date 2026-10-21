part of '../main.dart';

class _LocalProfile {
  const _LocalProfile({this.name, this.photo});

  final String? name;
  final Uint8List? photo;
}

/// Nama tampilan dan foto profil yang diubah pengguna, disimpan di perangkat
/// (SharedPreferences) per akun: kunci `guest` untuk tamu, uid untuk akun.
class _LocalProfileStore {
  const _LocalProfileStore._();

  static String _nameKey(String id) => 'horas.profile.$id.name';
  static String _photoKey(String id) => 'horas.profile.$id.photo';

  static Future<_LocalProfile> load(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_photoKey(id));
      return _LocalProfile(
        name: prefs.getString(_nameKey(id)),
        photo: encoded == null ? null : base64Decode(encoded),
      );
    } catch (_) {
      return const _LocalProfile();
    }
  }

  static Future<void> saveName(String id, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null || name.isEmpty) {
      await prefs.remove(_nameKey(id));
    } else {
      await prefs.setString(_nameKey(id), name);
    }
  }

  static Future<void> savePhoto(String id, Uint8List? bytes) async {
    final prefs = await SharedPreferences.getInstance();
    if (bytes == null) {
      await prefs.remove(_photoKey(id));
    } else {
      final saved = await prefs.setString(_photoKey(id), base64Encode(bytes));
      if (!saved) throw StateError('Penyimpanan perangkat menolak foto ini.');
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.size,
    required this.photo,
    required this.photoUrl,
  });

  final double size;
  final Uint8List? photo;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.55,
        color: scheme.onPrimaryContainer,
      ),
    );
    final Widget image;
    if (photo != null) {
      image = Image.memory(
        photo!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      image = Image.network(
        photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = fallback;
    }
    return ClipOval(child: image);
  }
}

/// Dialog edit nama. Memegang [TextEditingController] sendiri agar dibuang
/// dengan aman. Mengembalikan teks nama ('' berarti pakai nama bawaan),
/// atau null kalau dibatalkan.
class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.initialName, this.email});

  final String initialName;
  final String? email;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_nameController.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Edit profil'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Nama tampilan',
                helperText: 'Kosongkan untuk memakai nama bawaan.',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.email != null) ...[
              const SizedBox(height: 12),
              Text(
                'Email: ${widget.email} (dari akun Google, tidak bisa diubah)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen({
    required this.controller,
    required this.onOpenDictionary,
  });

  final AppController controller;
  final ValueChanged<String> onOpenDictionary;

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  bool _photoBusy = false;

  AppController get controller => widget.controller;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showPhotoOptions() async {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = controller.profilePhoto != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Ganti Foto'),
              subtitle: const Text('Pilih dari galeri'),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil Foto'),
              subtitle: const Text('Buka kamera'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.error,
                ),
                title: Text(
                  'Hapus Foto',
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
      case 'camera':
        await _pickPhoto(ImageSource.camera);
      case 'remove':
        await _removePhoto();
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    Uint8List? bytes;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null) bytes = await picked.readAsBytes();
    } on PlatformException catch (error) {
      final fromCamera = source == ImageSource.camera;
      if (error.code == 'camera_access_denied') {
        _toast(
          'Izin kamera ditolak. Aktifkan izin kamera di pengaturan perangkat.',
        );
      } else if (error.code == 'photo_access_denied') {
        _toast(
          'Izin galeri ditolak. Aktifkan izin foto di pengaturan perangkat.',
        );
      } else {
        _toast(
          fromCamera
              ? 'Kamera tidak dapat dibuka di perangkat ini.'
              : 'Galeri tidak dapat dibuka. Coba lagi.',
        );
      }
    } catch (_) {
      _toast(
        source == ImageSource.camera
            ? 'Kamera tidak dapat dibuka di perangkat ini.'
            : 'Galeri tidak dapat dibuka. Coba lagi.',
      );
    }
    if (!mounted) return;
    setState(() => _photoBusy = false);
    if (bytes == null) return; // dibatalkan atau gagal (pesan sudah tampil)

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pratinjau foto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.memory(
                bytes!,
                width: 180,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 14),
            const Text('Pakai foto ini sebagai foto profilmu?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _photoBusy = true);
    try {
      await controller.setProfilePhoto(bytes);
      _toast('Foto profil diperbarui.');
    } catch (error) {
      _toast('Foto belum tersimpan: $error');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus foto profil?'),
        content: const Text('Foto akan diganti dengan foto bawaan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      await controller.setProfilePhoto(null);
      _toast('Foto profil dihapus.');
    } catch (error) {
      _toast('Foto belum terhapus: $error');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _editProfile() async {
    final user = controller.currentUser;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditProfileDialog(
        initialName: controller.profileNameOverride ?? '',
        email: controller.userProfile?.email ?? user?.email,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await controller.setProfileName(result);
      _toast('Profil diperbarui.');
    } catch (error) {
      _toast('Profil belum tersimpan: $error');
    }
  }

  Future<void> _confirmLogout() async {
    final isGuest = controller.currentUser == null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isGuest ? 'Keluar dari mode tamu?' : 'Keluar dari akun?'),
        content: Text(
          isGuest
              ? 'Progres tamu tetap tersimpan di perangkat ini. Kamu akan '
                    'kembali ke halaman login.'
              : 'Kamu bisa masuk lagi kapan saja dengan akun Google yang sama.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (isGuest) {
        await controller.leaveGuestSession();
      } else {
        await controller.signOut();
      }
    } catch (error) {
      _toast('Tidak dapat keluar: $error');
    }
  }

  Widget _buildStat(ThemeData theme, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGroup(ThemeData theme, String title, List<Widget> tiles) {
    final scheme = theme.colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0)
        children.add(
          Divider(height: 1, indent: 56, color: scheme.outlineVariant),
        );
      children.add(tiles[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Icon(Icons.chevron_right_rounded, color: color),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final savedEntries = controller.savedEntries();
    final stats = controller.quizStats;
    final accuracy = stats.answeredQuestions == 0
        ? '—'
        : '${(stats.accuracy * 100).round()}%';
    final user = controller.currentUser;
    final authConfigured = controller.authRepository != null;
    final email = controller.userProfile?.email ?? user?.email;
    final photoUrl = controller.userProfile?.photoUrl ?? user?.photoUrl;
    final errors = <String>[
      if (controller.authError != null)
        'Status autentikasi tidak dapat dimuat: ${controller.authError}',
      if (controller.profileError != null)
        'Profil Firebase belum tersimpan: ${controller.profileError}',
      if (controller.progressError != null)
        'Progres belum tersinkronisasi: ${controller.progressError}',
    ];

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            children: [
              Center(
                child: Semantics(
                  button: true,
                  label: 'Ubah foto profil',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _photoBusy ? null : _showPhotoOptions,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ProfileAvatar(
                          size: 96,
                          photo: controller.profilePhoto,
                          photoUrl: photoUrl,
                        ),
                        if (_photoBusy)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.surface.withValues(alpha: 0.6),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.photo_camera_rounded,
                              size: 16,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                controller.displayName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (email != null) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: user == null
                        ? scheme.surfaceContainerHighest
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    user == null ? 'Tamu' : 'Akun Google',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: user == null
                          ? scheme.onSurfaceVariant
                          : scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    errors.join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  _buildStat(
                    theme,
                    '${stats.completedQuizzes}',
                    'Kuis selesai',
                  ),
                  const SizedBox(width: 10),
                  _buildStat(theme, accuracy, 'Akurasi'),
                  const SizedBox(width: 10),
                  _buildStat(theme, '${savedEntries.length}', 'Kata tersimpan'),
                ],
              ),
              const SizedBox(height: 24),
              _buildMenuGroup(theme, 'Akun', [
                _buildMenuTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit profil',
                  subtitle: 'Ubah nama tampilan',
                  onTap: _editProfile,
                ),
                if (user == null && authConfigured)
                  _buildMenuTile(
                    icon: Icons.login_rounded,
                    title: 'Masuk dengan Google',
                    subtitle: 'Simpan progres di akunmu',
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => _LoginScreen(controller: controller),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 18),
              _buildMenuGroup(theme, 'Lainnya', [
                _buildMenuTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Tentang Horas',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Horas',
                    applicationIcon: const HorasLogo.mark(size: 48),
                    children: const [
                      Text(
                        'Aplikasi belajar Bahasa Batak Toba: kamus dan kuis '
                        'kosakata.',
                      ),
                    ],
                  ),
                ),
                _buildMenuTile(
                  icon: Icons.logout_rounded,
                  title: user == null ? 'Keluar dari mode tamu' : 'Keluar',
                  color: scheme.error,
                  onTap: _confirmLogout,
                ),
              ]),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kata tersimpan',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${savedEntries.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (savedEntries.isEmpty)
                _EmptyState(
                  icon: Icons.bookmark_add_outlined,
                  title: 'Belum ada kata tersimpan',
                  message: 'Simpan kata dari kamus, lalu kembali ke sini untuk mengulanginya.',
                  actionLabel: 'Buka kamus',
                  onAction: () => widget.onOpenDictionary(''),
                )
              else
                ...savedEntries.map(
                  (entry) => _DictionaryEntryTile(
                    entry: entry,
                    saved: true,
                    onOpen: () => _showEntryDetails(context, entry, controller),
                    onToggleSaved: () => controller.toggleSaved(entry),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

