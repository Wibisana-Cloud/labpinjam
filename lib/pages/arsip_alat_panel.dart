import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../config/blockchain_config.dart';
import '../services/blockchain_service.dart';

class ArsipAlatPage extends StatefulWidget {
  final ReownAppKitModal appKit;
  const ArsipAlatPage({super.key, required this.appKit});
  @override
  State<ArsipAlatPage> createState() => _ArsipAlatPageState();
}

class _ArsipAlatPageState extends State<ArsipAlatPage> {
  bool _sibuk = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sibuk,
    child: Scaffold(
      appBar: AppBar(title: const Text('Arsipkan alat')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ArsipAlatPanel(
          appKit: widget.appKit,
          onBusyChanged: (value) {
            if (mounted) setState(() => _sibuk = value);
          },
        ),
      ),
    ),
  );
}

class ArsipAlatPanel extends StatefulWidget {
  final ReownAppKitModal appKit;
  final ValueChanged<bool> onBusyChanged;

  const ArsipAlatPanel({
    super.key,
    required this.appKit,
    required this.onBusyChanged,
  });

  @override
  State<ArsipAlatPanel> createState() => _ArsipAlatPanelState();
}

class _ArsipAlatPanelState extends State<ArsipAlatPanel> {
  final _form = GlobalKey<FormState>();
  final _kode = TextEditingController();
  final _service = BlockchainService();

  bool _sibuk = false;
  bool _dikirimKeWallet = false;
  bool _selesai = false;
  bool _berhasil = false;
  String? _hash;
  String? _pesan;

  bool get _terkunci => _sibuk || _dikirimKeWallet;

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() => _sibuk = value);
    widget.onBusyChanged(value);
  }

  Future<void> _kirim() async {
    if (_terkunci || !(_form.currentState?.validate() ?? false)) return;
    final setuju = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arsipkan alat?'),
        content: Text(
          'Alat ${_kode.text.trim()} tidak dapat dipinjam lagi. Riwayat tetap tersimpan. Arsip tidak dapat dibatalkan pada versi ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (!mounted || setuju != true) return;
    _setBusy(true);
    setState(() => _pesan = 'Memeriksa admin dan kode alat...');

    try {
      final kit = widget.appKit;
      final session = kit.session;
      final alamat = session?.getAddress('eip155');
      final chain = 'eip155:${BlockchainConfig.chainId}';
      if (!kit.isConnected || session == null || alamat == null) {
        throw StateError('Hubungkan wallet admin terlebih dahulu.');
      }
      final approved = kit.getApprovedChains(namespace: 'eip155') ?? [];
      if (!approved.contains(chain)) {
        throw StateError(
          'Hubungkan kembali wallet dan setujui Ethereum Sepolia.',
        );
      }

      final data = await _service.buatDataArsipAlat(
        pengirim: alamat,
        kode: _kode.text.trim(),
      );
      if (!mounted) return;

      if (!kit.isConnected ||
          kit.session?.topic != session.topic ||
          kit.session?.getAddress('eip155')?.toLowerCase() !=
              alamat.toLowerCase()) {
        throw StateError('Akun berubah. Periksa wallet lalu coba kembali.');
      }

      setState(() {
        _dikirimKeWallet = true;
        _pesan = 'Setujui pengarsipan alat di MetaMask.';
      });

      final result = await kit.request(
        topic: session.topic,
        chainId: chain,
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [
            {
              'from': alamat,
              'to': BlockchainConfig.contractAddress,
              'value': '0x0',
              'data': data,
            },
          ],
        ),
      );
      if (!mounted) return;
      if (result is! String ||
          !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(result)) {
        throw StateError(
          'Respons wallet tidak berisi hash transaksi yang valid.',
        );
      }
      setState(() {
        _hash = result;
        _pesan = 'Transaksi dikirim. Memeriksa konfirmasi...';
      });
      await _bacaKonfirmasi();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final detail = BlockchainService.pesanErrorAman(error);
        if (_hash != null) {
          _pesan =
              'Transaksi sudah dikirim. Konfirmasi belum dapat diperiksa. '
              'Tekan Cek konfirmasi lagi.\n\n$detail';
        } else if (_dikirimKeWallet) {
          _pesan =
              'Permintaan ditolak atau hasilnya belum dapat dipastikan. '
              'Periksa aktivitas MetaMask sebelum mencoba ulang.\n\n$detail';
        } else {
          _pesan = detail;
        }
      });
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _bacaKonfirmasi() async {
    final hash = _hash;
    if (hash == null) return;
    final sukses = await _service.cekTransaksi(hash);
    if (!mounted) return;
    setState(() {
      if (sukses == null) {
        _pesan =
            'Menunggu konfirmasi blockchain. '
            'Tekan Cek konfirmasi beberapa saat lagi.';
      } else {
        _selesai = true;
        _berhasil = sukses;
        _pesan = sukses
            ? 'Alat ${_kode.text.trim()} berhasil diarsipkan. '
                  'Kembali ke beranda untuk melihat daftar terbaru.'
            : 'Transaksi gagal di blockchain. Alat tidak diarsipkan. '
                  'Periksa apakah alat sedang dipinjam atau telah diarsipkan.';
      }
    });
  }

  Future<void> _cek() async {
    if (_sibuk || _hash == null) return;
    _setBusy(true);
    try {
      await _bacaKonfirmasi();
    } catch (error) {
      if (mounted) {
        setState(
          () => _pesan =
              'Belum dapat memeriksa konfirmasi. '
              'Jangan kirim ulang transaksi.\n'
              '${BlockchainService.pesanErrorAman(error)}',
        );
      }
    } finally {
      _setBusy(false);
    }
  }

  void _formBaru() {
    if (!_selesai || _sibuk) return;
    _kode.clear();
    setState(() {
      _dikirimKeWallet = false;
      _selesai = false;
      _berhasil = false;
      _hash = null;
      _pesan = null;
    });
  }

  Future<void> _salin(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Disalin ke clipboard')));
  }

  @override
  void dispose() {
    _kode.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Arsipkan alat',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Khusus alat yang tersedia. Riwayat tidak dihapus.'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _kode,
                enabled: !_terkunci,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Kode alat yang akan diarsipkan',
                  hintText: 'ESP32-02',
                  helperText: 'Huruf besar, angka, dan tanda minus.',
                ),
                validator: BlockchainService.validasiKode,
              ),
              const SizedBox(height: 16),
              const Text(
                'Persetujuan melalui MetaMask • Gas Sepolia ETH',
                style: TextStyle(fontSize: 12),
              ),
              if (_pesan != null) ...[
                const SizedBox(height: 16),
                Text(
                  _pesan!,
                  style: TextStyle(
                    color: _berhasil ? const Color(0xFF087F72) : null,
                  ),
                ),
              ],
              if (_hash != null) ...[
                const SizedBox(height: 12),
                SelectableText('Hash: $_hash'),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => _salin(_hash!),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Salin hash'),
                    ),
                    TextButton(
                      onPressed: () =>
                          _salin('https://sepolia.etherscan.io/tx/$_hash'),
                      child: const Text('Salin tautan Etherscan'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              if (_sibuk)
                const Center(child: CircularProgressIndicator())
              else if (_selesai)
                FilledButton(
                  onPressed: _formBaru,
                  child: const Text('Form baru'),
                )
              else if (_hash != null)
                FilledButton(
                  onPressed: _cek,
                  child: const Text('Cek konfirmasi'),
                )
              else if (!_dikirimKeWallet)
                FilledButton.icon(
                  onPressed: _kirim,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Arsipkan melalui MetaMask'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
