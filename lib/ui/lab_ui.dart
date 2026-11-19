import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData buildLabTheme() {
  const teal = Color(0xFF087F72);
  const ink = Color(0xFF173B34);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: teal),
  );
  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF5F8F7),
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F8F7),
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE2EAE6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      errorMaxLines: 3,
      helperMaxLines: 3,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFDCE7E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: teal, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: const Color(0xFFD7EFE6),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFDCE7E1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: ink),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE2EAE6)),
  );
}

class LabSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const LabSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F5F0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: const Color(0xFF087F72), size: 24),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF667773),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class LabNotice extends StatelessWidget {
  final String text;
  final bool loading;
  final bool success;
  final bool error;
  const LabNotice({
    super.key,
    required this.text,
    this.loading = false,
    this.success = false,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = error
        ? const Color(0xFFAF3434)
        : success
        ? const Color(0xFF087F72)
        : const Color(0xFF426587);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error
            ? const Color(0xFFFFEEEE)
            : success
            ? const Color(0xFFE5F5F0)
            : const Color(0xFFEDF3F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(
              error
                  ? Icons.error_outline
                  : success
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: color,
              size: 22,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: color, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

Future<void> _copy(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Disalin ke clipboard')));
}

class AddressTile extends StatelessWidget {
  final String address;
  const AddressTile({super.key, required this.address});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ALAMAT WALLET',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: Color(0xFF667773),
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(address, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Salin alamat',
          onPressed: () => _copy(context, address),
          icon: const Icon(Icons.copy_rounded, size: 18),
        ),
      ],
    ),
  );
}

class TransactionHashTile extends StatelessWidget {
  final String hash;
  const TransactionHashTile({super.key, required this.hash});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BUKTI TRANSAKSI',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
            color: Color(0xFF667773),
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(hash, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            TextButton.icon(
              onPressed: () => _copy(context, hash),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Salin hash'),
            ),
            TextButton(
              onPressed: () =>
                  _copy(context, 'https://sepolia.etherscan.io/tx/$hash'),
              child: const Text('Salin tautan Etherscan'),
            ),
          ],
        ),
      ],
    ),
  );
}
