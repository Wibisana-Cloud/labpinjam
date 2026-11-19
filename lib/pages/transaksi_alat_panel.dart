import '../ui/lab_ui.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../config/blockchain_config.dart';
import '../services/blockchain_service.dart';

class TransaksiAlatPanel extends StatefulWidget {
  final ReownAppKitModal appKit;
  final String kode;
  final bool kembalikan;

  const TransaksiAlatPanel({
    super.key,
    required this.appKit,
    required this.kode,
    required this.kembalikan,
  });

  @override
  State<TransaksiAlatPanel> createState() => _TransaksiAlatPanelState();
}

class _TransaksiAlatPanelState extends State<TransaksiAlatPanel> {
  final BlockchainService _service = BlockchainService();

  bool _sibuk = false;
  bool _selesai = false;
  bool _berhasil = false;
  bool _permintaanDikirim = false;

  String? _hash;
  String? _pesan;

  String get _aksi => widget.kembalikan ? 'Kembalikan' : 'Pinjam';

  Future<void> _kirim() async {
    if (_sibuk || _permintaanDikirim || _selesai) return;

    setState(() {
      _sibuk = true;
      _pesan = 'Memeriksa status alat...';
    });

    try {
      final appKit = widget.appKit;
      final session = appKit.session;
      final alamat = session?.getAddress('eip155');

      if (!appKit.isConnected || session == null || alamat == null) {
        throw StateError('Hubungkan MetaMask terlebih dahulu.');
      }

      const chain = 'eip155:11155111';

      final approved =
          appKit.getApprovedChains(namespace: 'eip155') ?? <String>[];

      if (!approved.contains(chain)) {
        throw StateError(
          'Sepolia belum disetujui. Disconnect lalu hubungkan '
          'MetaMask kembali dengan Ethereum Sepolia.',
        );
      }

      final data = await _service.buatDataTransaksi(
        kode: widget.kode,
        peminjam: alamat,
        kembalikan: widget.kembalikan,
      );

      if (!mounted) return;

      // Pastikan akun tidak berubah selama pemeriksaan.
      final alamatSekarang = appKit.session?.getAddress('eip155');

      if (!appKit.isConnected ||
          alamatSekarang?.toLowerCase() != alamat.toLowerCase()) {
        throw StateError('Akun wallet berubah. Silakan coba kembali.');
      }

      setState(() {
        _permintaanDikirim = true;
        _pesan = 'Setujui transaksi di MetaMask.';
      });

      final hasil = await appKit.request(
        topic: session.topic,
        chainId: chain,
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [
            {
              'from': alamat,
              'to': BlockchainConfig.contractAddress,
              'data': data,
              'value': '0x0',
            },
          ],
        ),
      );

      if (hasil is! String || !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(hasil)) {
        throw StateError('Wallet tidak mengembalikan hash transaksi.');
      }

      if (!mounted) return;

      setState(() {
        _hash = hasil;
        _pesan = 'Transaksi dikirim. Memeriksa konfirmasi...';
      });

      await _periksaKonfirmasi();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        if (_hash != null) {
          _pesan =
              'Transaksi sudah dikirim, tetapi konfirmasi belum '
              'dapat diperiksa. Tekan Cek konfirmasi lagi.';
        } else if (_permintaanDikirim) {
          _pesan =
              'Permintaan ditolak atau hasilnya belum dapat dipastikan. '
              'Periksa aktivitas MetaMask sebelum mencoba kembali.\n\n'
              '${BlockchainService.pesanErrorAman(error)}';
        } else {
          _pesan = BlockchainService.pesanErrorAman(error);
        }
      });
    } finally {
      if (mounted) {
        setState(() => _sibuk = false);
      }
    }
  }

  Future<void> _periksaKonfirmasi() async {
    final hash = _hash;
    if (hash == null) return;

    final sukses = await _service.cekTransaksi(hash);

    if (!mounted) return;

    if (sukses == null) {
      setState(() {
        _pesan =
            'Transaksi menunggu konfirmasi. '
            'Tekan Cek konfirmasi beberapa saat lagi.';
      });
      return;
    }

    setState(() {
      _selesai = true;
      _berhasil = sukses;
      _pesan = sukses
          ? 'Transaksi berhasil dikonfirmasi. '
                'Kembali untuk melihat status terbaru.'
          : 'Transaksi gagal di blockchain. '
                'Kembali untuk memperbarui status alat.';
    });
  }

  Future<void> _cek() async {
    if (_sibuk) return;

    setState(() => _sibuk = true);

    try {
      await _periksaKonfirmasi();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _pesan =
            'Konfirmasi belum dapat diperiksa. '
            'Periksa internet dan coba lagi. '
            'Jangan kirim ulang transaksi yang sama.';
      });
    } finally {
      if (mounted) {
        setState(() => _sibuk = false);
      }
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabSectionTitle(
              icon: widget.kembalikan
                  ? Icons.assignment_return_outlined
                  : Icons.output,
              title: '$_aksi alat',
              subtitle: widget.kode,
            ),
            const SizedBox(height: 12),
            const Text(
              'Setujui transaksi di MetaMask. '
              'Biaya gas menggunakan Sepolia ETH.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_pesan != null) ...[
              LabNotice(
                text: _pesan!,
                loading: _sibuk,
                success: _berhasil,
                error: _selesai && !_berhasil,
              ),
              const SizedBox(height: 16),
            ],
            if (_hash != null) ...[
              TransactionHashTile(hash: _hash!),
              const SizedBox(height: 16),
            ],
            if (_sibuk)
              const Center(child: CircularProgressIndicator())
            else if (_selesai)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Kembali ke detail alat'),
              )
            else if (_hash != null)
              FilledButton(onPressed: _cek, child: const Text('Cek konfirmasi'))
            else if (!_permintaanDikirim)
              FilledButton(
                onPressed: widget.appKit.isConnected ? _kirim : null,
                child: Text('$_aksi melalui MetaMask'),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali ke detail alat'),
              ),
          ],
        ),
      ),
    );
  }
}
