import 'package:flutter/material.dart';

/// Logo Horas (gelembung bicara dengan motif Batak), dari aset PNG transparan.
///
/// - [HorasLogo.full]: bubble + tulisan "Horas!". Memakai versi bertulisan
///   terang saat tema gelap supaya tetap terbaca.
/// - [HorasLogo.mark]: hanya bubble, untuk tempat yang sempit.
///
/// Aset WebP dibuat oleh `tools/make_brand_assets.py` dari satu gambar master.
class HorasLogo extends StatelessWidget {
  const HorasLogo.full({super.key, this.width = 220}) : _isMark = false;

  const HorasLogo.mark({super.key, double size = 40})
    : width = size,
      _isMark = true;

  /// Lebar tampilan (dp). Tinggi mengikuti rasio gambar.
  final double width;
  final bool _isMark;

  static const fullAsset = 'assets/images/horas_logo.webp';
  static const fullDarkAsset = 'assets/images/horas_logo_dark.webp';
  static const markAsset = 'assets/images/horas_mark.webp';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final asset = _isMark ? markAsset : (isDark ? fullDarkAsset : fullAsset);
    return Image.asset(
      asset,
      width: width,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Horas',
      // Jika aset gagal dimuat, tampilan tetap utuh dengan ikon pengganti.
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.menu_book_rounded,
        size: width * 0.6,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
