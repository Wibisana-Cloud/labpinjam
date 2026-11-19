import 'dart:async';
import 'ui/lab_ui.dart';
import 'package:flutter/material.dart';

import 'pages/detail_alat_page.dart';
import 'pages/wallet_page.dart';
import 'services/blockchain_service.dart';
import 'services/wallet_pilihan.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LabPinjam',
      debugShowCheckedModeBanner: false,
      theme: buildLabTheme(),
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFE8EFED),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      home: const DaftarAlatPage(),
    );
  }
}

class DaftarAlatPage extends StatefulWidget {
  const DaftarAlatPage({super.key});

  @override
  State<DaftarAlatPage> createState() => _DaftarAlatPageState();
}

class _DaftarAlatPageState extends State<DaftarAlatPage> {
  final BlockchainService _service = BlockchainService();
  final TextEditingController _pencarian = TextEditingController();

  List<Alat> _daftarAlat = [];
  int _jumlahKontrak = 0;
  bool _memuat = true;
  String? _pesanError;
  String _filter = 'Aktif';
  String _kataKunci = '';
  DateTime? _diperbarui;
  StreamSubscription<void>? _eventSubscription;
  Timer? _eventDebounce;
  bool _sedangMemuat = false;
  bool _muatLagi = false;
  bool _eventGagal = false;

  @override
  void initState() {
    super.initState();
    WalletPilihan.alamat.addListener(_walletBerubah);
    _mulaiPantauEvent();
    _muatAlat();
  }

  void _walletBerubah() {
    if (mounted) setState(() {});
  }

  void _mulaiPantauEvent() {
    _eventSubscription = _service.pantauPerubahanAlat().listen(
      (_) {
        if (!mounted) return;
        if (_eventGagal) setState(() => _eventGagal = false);
        _eventDebounce?.cancel();
        _eventDebounce = Timer(const Duration(milliseconds: 500), () {
          if (mounted) unawaited(_muatAlat());
        });
      },
      onError: (Object error) {
        if (mounted) setState(() => _eventGagal = true);
      },
    );
  }

  Future<void> _ulangPantauEvent() async {
    await _eventSubscription?.cancel();
    if (!mounted) return;
    setState(() => _eventGagal = false);
    _mulaiPantauEvent();
    await _muatAlat();
  }

  Future<void> _muatAlat() async {
    if (!mounted) return;
    if (_sedangMemuat) {
      _muatLagi = true;
      return;
    }
    _sedangMemuat = true;

    setState(() {
      _memuat = true;
      _pesanError = null;
    });

    try {
      final daftar = await _service.ambilDaftarAlat();
      final jumlah = await _service.ambilJumlahAlat();

      if (!mounted) return;

      setState(() {
        _daftarAlat = daftar;
        _jumlahKontrak = jumlah;
        _diperbarui = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;

      debugPrint(BlockchainService.pesanErrorAman(error));

      setState(() {
        _pesanError =
            'Data belum dapat diperbarui. '
            'Periksa konfigurasi dan koneksi.\n'
            '${BlockchainService.pesanErrorAman(error)}';
      });
    } finally {
      _sedangMemuat = false;
      if (mounted) {
        setState(() => _memuat = false);
        if (_muatLagi) {
          _muatLagi = false;
          unawaited(_muatAlat());
        }
      }
    }
  }

  List<Alat> get _hasilPencarian {
    final kata = _kataKunci.trim().toLowerCase();

    return _daftarAlat.where((alat) {
      final cocokPencarian =
          alat.kode.toLowerCase().contains(kata) ||
          alat.nama.toLowerCase().contains(kata);

      final cocokStatus = alat.cocokFilter(
        _filter,
        wallet: WalletPilihan.alamat.value,
      );

      return cocokPencarian && cocokStatus;
    }).toList();
  }

  Future<void> _bukaDetail(Alat alat) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => DetailAlatPage(kode: alat.kode)),
    );

    if (mounted) {
      await _muatAlat();
    }
  }

  @override
  void dispose() {
    WalletPilihan.alamat.removeListener(_walletBerubah);
    _eventDebounce?.cancel();
    unawaited(_eventSubscription?.cancel());
    _pencarian.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tersedia = _daftarAlat.where((alat) => alat.tersedia).length;
    final hasil = _hasilPencarian;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_rounded, color: Color(0xFF087F72)),
            SizedBox(width: 10),
            Text('LabPinjam', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Wallet & admin',
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const WalletPage()),
              );
              if (mounted && !_memuat) await _muatAlat();
            },
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (!_memuat) await _muatAlat();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _banner(),
            if (_eventGagal)
              ListTile(
                leading: const Icon(Icons.sync_problem),
                title: const Text(
                  'Pembaruan otomatis terputus. Tarik layar untuk refresh.',
                ),
                trailing: TextButton(
                  onPressed: _ulangPantauEvent,
                  child: const Text('Sambung'),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                _ringkasan(
                  'Total alat',
                  _jumlahKontrak,
                  Icons.inventory_2_outlined,
                  const Color(0xFF476477),
                ),
                const SizedBox(width: 10),
                _ringkasan(
                  'Tersedia',
                  tersedia,
                  Icons.check_circle_outline,
                  const Color(0xFF087F72),
                ),
                const SizedBox(width: 10),
                _ringkasan(
                  'Dipinjam',
                  _daftarAlat
                      .where((alat) => !alat.diarsipkan && !alat.tersedia)
                      .length,
                  Icons.schedule,
                  const Color(0xFFAD6500),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Jelajahi alat',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Temukan perangkat untuk praktik dan proyekmu.',
              style: TextStyle(color: Color(0xFF667773)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pencarian,
              onChanged: (value) {
                setState(() => _kataKunci = value);
              },
              decoration: InputDecoration(
                hintText: 'Cari nama atau kode alat',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _kataKunci.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        onPressed: () {
                          _pencarian.clear();
                          setState(() => _kataKunci = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                    'Semua',
                    'Aktif',
                    'Tersedia',
                    'Dipinjam',
                    'Pinjaman saya',
                    'Arsip',
                  ].map((label) {
                    return ChoiceChip(
                      label: Text(label),
                      selected: _filter == label,
                      onSelected: (_) => setState(() => _filter = label),
                      showCheckmark: false,
                    );
                  }).toList(),
            ),
            const SizedBox(height: 18),
            if (_filter == 'Pinjaman saya')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  WalletPilihan.alamat.value == null
                      ? 'Buka Wallet dan hubungkan akun untuk melihat pinjaman Anda.'
                      : 'Filter wallet: ${WalletPilihan.alamat.value}. Buka Wallet untuk mengganti akun.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (_memuat)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            if (_pesanError != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_pesanError!),
                    if (_daftarAlat.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Menampilkan data terakhir yang dimuat.'),
                      ),
                    TextButton(
                      onPressed: _memuat ? null : _muatAlat,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!_memuat && hasil.isEmpty && _pesanError == null) _kosong(),
            ...hasil.map(_kartuAlat),
            if (_diperbarui != null) ...[
              const SizedBox(height: 10),
              Text(
                'Diperbarui pukul '
                '${_diperbarui!.hour.toString().padLeft(2, '0')}:'
                '${_diperbarui!.minute.toString().padLeft(2, '0')}'
                ' • Tarik layar untuk memperbarui',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF667773)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _banner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF075E56), Color(0xFF149E8B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                'LABORATORIUM DIGITAL',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Text(
            'Ruang untuk\nide besarmu.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Pinjam perangkat dan pantau riwayatnya '
            'dalam satu aplikasi.',
            style: TextStyle(color: Colors.white, height: 1.5),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: Color(0xFF98EBD8)),
              SizedBox(width: 8),
              Text(
                'Ethereum Sepolia • Jaringan uji',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ringkasan(String label, int jumlah, IconData icon, Color warna) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2EAE8)),
        ),
        child: Column(
          children: [
            Icon(icon, color: warna, size: 22),
            const SizedBox(height: 10),
            Text(
              _diperbarui == null ? '—' : '$jumlah',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuAlat(Alat alat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _bukaDetail(alat),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F5F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.memory_rounded,
                        size: 30,
                        color: Color(0xFF087F72),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: alat.tersedia
                            ? const Color(0xFFE5F5F0)
                            : const Color(0xFFFFF1DD),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        alat.diarsipkan
                            ? 'Diarsipkan'
                            : alat.tersedia
                            ? 'Tersedia'
                            : 'Dipinjam',
                        style: TextStyle(
                          color: alat.tersedia
                              ? const Color(0xFF087F72)
                              : const Color(0xFFAD6500),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  alat.nama,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  alat.kode,
                  style: const TextStyle(color: Color(0xFF667773)),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFEAF0EE)),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Text(
                      'Lihat detail & riwayat',
                      style: TextStyle(
                        color: Color(0xFF087F72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Color(0xFF087F72),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kosong() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 56,
            color: Color(0xFF8CA29C),
          ),
          const SizedBox(height: 14),
          Text(
            _daftarAlat.isEmpty
                ? 'Belum ada alat terdaftar.'
                : 'Tidak ada alat yang cocok.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text('Coba muat ulang atau ubah pencarian dan filter.'),
        ],
      ),
    );
  }
}
