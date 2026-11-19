import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/blockchain_service.dart';
import 'wallet_page.dart';

class DetailAlatPage extends StatefulWidget {
  final String kode;

  const DetailAlatPage({super.key, required this.kode});

  @override
  State<DetailAlatPage> createState() => _DetailAlatPageState();
}

class _DetailAlatPageState extends State<DetailAlatPage> {
  final BlockchainService _service = BlockchainService();

  List<RiwayatPeminjaman> _riwayat = [];
  bool _tersedia = false;
  bool _memuat = true;
  bool _membukaWallet = false;
  String? _pesanError;

  Alat? _alat;
  String get _nama => _alat?.nama ?? widget.kode;
  String get _deskripsi => (_alat?.deskripsi.isNotEmpty ?? false)
      ? _alat!.deskripsi
      : 'Belum ada deskripsi untuk alat ini.';

  @override
  void initState() {
    super.initState();
    _muatRiwayat();
  }

  Future<void> _muatRiwayat() async {
    if (!mounted) return;

    setState(() {
      _memuat = true;
      _pesanError = null;
    });

    try {
      final riwayat = await _service.ambilRiwayat(widget.kode);
      final alat = await _service.ambilAlat(widget.kode);

      if (!mounted) return;

      setState(() {
        _riwayat = riwayat;
        _tersedia = alat.tersedia;
        _alat = alat;
      });
    } catch (error) {
      if (!mounted) return;

      debugPrint(BlockchainService.pesanErrorAman(error));

      setState(() {
        _pesanError =
            'Data alat belum dapat dimuat. Periksa internet dan coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() => _memuat = false);
      }
    }
  }

  Future<void> _bukaTransaksi() async {
    if (_membukaWallet ||
        _memuat ||
        _pesanError != null ||
        (_alat?.diarsipkan ?? false)) {
      return;
    }

    setState(() => _membukaWallet = true);

    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => WalletPage(kode: widget.kode, kembalikan: !_tersedia),
        ),
      );

      if (mounted) {
        await _muatRiwayat();
      }
    } finally {
      if (mounted) {
        setState(() => _membukaWallet = false);
      }
    }
  }

  Future<void> _salin(String nilai, String label) async {
    await Clipboard.setData(ClipboardData(text: nilai));

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label disalin')));
  }

  String _formatWaktu(DateTime waktu) {
    final lokal = waktu.toLocal();

    String dua(int angka) => angka.toString().padLeft(2, '0');

    return '${dua(lokal.day)}/${dua(lokal.month)}/${lokal.year}'
        ' • ${dua(lokal.hour)}:${dua(lokal.minute)}';
  }

  String _alamatSingkat(String alamat) {
    if (alamat.length < 15) return alamat;

    return '${alamat.substring(0, 8)}...'
        '${alamat.substring(alamat.length - 6)}';
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail alat',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _memuat ? null : _muatRiwayat,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buatIsiHalaman(),
      bottomNavigationBar:
          _memuat || _pesanError != null || (_alat?.diarsipkan ?? false)
          ? null
          : _tombolTransaksi(),
    );
  }

  Widget _buatIsiHalaman() {
    if (_memuat) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pesanError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: Color(0xFF8CA29C),
              ),
              const SizedBox(height: 16),
              Text(_pesanError!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _muatRiwayat,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (!_memuat) await _muatRiwayat();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _heroAlat(),
          const SizedBox(height: 24),
          Text(
            _nama,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                widget.kode,
                style: const TextStyle(
                  color: Color(0xFF667773),
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                tooltip: 'Salin kode alat',
                onPressed: () => _salin(widget.kode, 'Kode alat'),
                icon: const Icon(Icons.copy_rounded, size: 17),
              ),
            ],
          ),
          Text(
            _deskripsi,
            style: const TextStyle(color: Color(0xFF667773), height: 1.6),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _label(Icons.category_outlined, 'Alat laboratorium'),
              _label(Icons.public, 'Sepolia'),
              _label(Icons.history_rounded, '${_riwayat.length} peminjaman'),
            ],
          ),
          const SizedBox(height: 24),
          _informasiPeminjaman(),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Riwayat peminjaman',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_riwayat.length}',
                  style: const TextStyle(
                    color: Color(0xFF087F72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Aktivitas terbaru ditampilkan paling atas.',
            style: TextStyle(color: Color(0xFF667773), fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (_riwayat.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 42,
                    color: Color(0xFF8CA29C),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Riwayat masih kosong',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Peminjaman yang berhasil akan tercatat di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF667773)),
                  ),
                ],
              ),
            ),
          ..._riwayat.map(_kartuRiwayat),
        ],
      ),
    );
  }

  Widget _heroAlat() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F3ED), Color(0xFFEEF8F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _tersedia
                    ? const Color(0xFF087F72)
                    : const Color(0xFFAD6500),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                (_alat?.diarsipkan ?? false)
                    ? 'Diarsipkan'
                    : _tersedia
                    ? 'Siap dipinjam'
                    : 'Sedang dipinjam',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Icon(
              Icons.memory_rounded,
              size: 100,
              color: Color(0xFF087F72),
            ),
          ),
          const Text(
            'PERANGKAT LABORATORIUM',
            style: TextStyle(
              letterSpacing: 1.8,
              fontSize: 10,
              color: Color(0xFF52766B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(IconData icon, String teks) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2EAE8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF667773)),
          const SizedBox(width: 7),
          Text(teks, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _informasiPeminjaman() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF45689B),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              (_alat?.diarsipkan ?? false)
                  ? 'Alat telah diarsipkan. Riwayat tetap tersedia; alat tidak dapat dipinjam.'
                  : _tersedia
                  ? 'Hubungkan MetaMask dan setujui transaksi '
                        'untuk mencatat peminjaman alat.'
                  : 'Alat hanya dapat dikembalikan menggunakan '
                        'wallet yang melakukan peminjaman.',
              style: const TextStyle(color: Color(0xFF34547F), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuRiwayat(RiwayatPeminjaman catatan) {
    final aktif = catatan.waktuKembali == null;
    final warna = aktif ? const Color(0xFFAD6500) : const Color(0xFF087F72);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                aktif ? Icons.schedule_rounded : Icons.task_alt_rounded,
                color: warna,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  aktif ? 'Peminjaman aktif' : 'Selesai dikembalikan',
                  style: TextStyle(fontWeight: FontWeight.w700, color: warna),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'WALLET PEMINJAM',
            style: TextStyle(
              color: Color(0xFF667773),
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: catatan.peminjam,
                  child: Text(
                    _alamatSingkat(catatan.peminjam),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Salin alamat lengkap',
                onPressed: () => _salin(catatan.peminjam, 'Alamat wallet'),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const Divider(color: Color(0xFFEAF0EE)),
          const SizedBox(height: 8),
          _barisWaktu('Dipinjam', _formatWaktu(catatan.waktuPinjam)),
          const SizedBox(height: 10),
          _barisWaktu(
            'Dikembalikan',
            aktif ? 'Belum dikembalikan' : _formatWaktu(catatan.waktuKembali!),
          ),
        ],
      ),
    );
  }

  Widget _barisWaktu(String label, String nilai) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF667773), fontSize: 12),
          ),
        ),
        Text(
          nilai,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _tombolTransaksi() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2EAE8))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _membukaWallet ? null : _bukaTransaksi,
                  icon: Icon(
                    _tersedia
                        ? Icons.output_rounded
                        : Icons.assignment_return_outlined,
                  ),
                  label: Text(
                    _membukaWallet
                        ? 'Membuka wallet...'
                        : _tersedia
                        ? 'Pinjam alat'
                        : 'Kembalikan alat',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Persetujuan melalui MetaMask • Gas Sepolia ETH',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667773), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
