import '../ui/lab_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../config/blockchain_config.dart';
import '../services/blockchain_service.dart';

class TambahAlatPanel extends StatefulWidget {
  final ReownAppKitModal appKit;
  final ValueChanged<bool> onBusyChanged;

  const TambahAlatPanel({
    super.key,
    required this.appKit,
    required this.onBusyChanged,
  });

  @override
  State<TambahAlatPanel> createState() => _TambahAlatPanelState();
}

class _TambahAlatPanelState extends State<TambahAlatPanel> {
  final _form = GlobalKey<FormState>();
  final _kode = TextEditingController();
  final _nama = TextEditingController();
  final _deskripsi = TextEditingController();
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

      final data = await _service.buatDataTambahAlat(
        pengirim: alamat,
        kode: _kode.text.trim(),
        nama: _nama.text.trim(),
        deskripsi: _deskripsi.text.trim(),
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
        _pesan = 'Setujui penambahan alat di MetaMask.';
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
            ? 'Alat ${_kode.text.trim()} berhasil ditambahkan. '
                  'Kembali ke beranda untuk melihat daftar terbaru.'
            : 'Transaksi gagal di blockchain. Alat tidak ditambahkan. '
                  'Kode mungkin telah digunakan; periksa daftar alat.';
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
    _nama.clear();
    _deskripsi.clear();
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
    _nama.dispose();
    _deskripsi.dispose();
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
              const LabSectionTitle(
                icon: Icons.add_box_outlined,
                title: 'Tambah alat',
                subtitle:
                    'Isi identitas perangkat, lalu setujui melalui MetaMask.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _kode,
                enabled: !_terkunci,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Kode unik',
                  hintText: 'ESP32-02',
                  helperText: 'Contoh: ESP32-02. Kode tidak boleh sama.',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
                validator: BlockchainService.validasiKode,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nama,
                enabled: !_terkunci,
                decoration: const InputDecoration(
                  labelText: 'Nama alat',
                  hintText: 'ESP32 Development Board',
                  prefixIcon: Icon(Icons.memory_rounded),
                ),
                validator: BlockchainService.validasiNama,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deskripsi,
                enabled: !_terkunci,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                ),
                validator: BlockchainService.validasiDeskripsi,
              ),
              const SizedBox(height: 16),
              const Text(
                'Persetujuan melalui MetaMask • Gas Sepolia ETH',
                style: TextStyle(fontSize: 12),
              ),
              if (_pesan != null) ...[
                const SizedBox(height: 16),
                LabNotice(
                  text: _pesan!,
                  loading: _sibuk,
                  success: _berhasil,
                  error: _selesai && !_berhasil,
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
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah melalui MetaMask'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
