import '../ui/lab_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../config/blockchain_config.dart';
import '../services/blockchain_service.dart';

class UbahAlatPage extends StatefulWidget {
  final ReownAppKitModal appKit;
  const UbahAlatPage({super.key, required this.appKit});
  @override
  State<UbahAlatPage> createState() => _UbahAlatPageState();
}

class _UbahAlatPageState extends State<UbahAlatPage> {
  bool _sibuk = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sibuk,
    child: Scaffold(
      appBar: AppBar(title: const Text('Edit alat')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: UbahAlatPanel(
          appKit: widget.appKit,
          onBusyChanged: (value) {
            if (mounted) setState(() => _sibuk = value);
          },
        ),
      ),
    ),
  );
}

class UbahAlatPanel extends StatefulWidget {
  final ReownAppKitModal appKit;
  final ValueChanged<bool> onBusyChanged;

  const UbahAlatPanel({
    super.key,
    required this.appKit,
    required this.onBusyChanged,
  });

  @override
  State<UbahAlatPanel> createState() => _UbahAlatPanelState();
}

class _UbahAlatPanelState extends State<UbahAlatPanel> {
  final _form = GlobalKey<FormState>();
  final _kode = TextEditingController();
  final _nama = TextEditingController();
  final _deskripsi = TextEditingController();
  final _service = BlockchainService();

  bool _sibuk = false;
  bool _dikirimKeWallet = false;
  bool _selesai = false;
  bool _berhasil = false;
  String? _kodeDimuat;
  String? _hash;
  String? _pesan;

  bool get _terkunci => _sibuk || _dikirimKeWallet;

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() => _sibuk = value);
    widget.onBusyChanged(value);
  }

  Future<void> _muatAlat() async {
    if (_terkunci) return;
    final error = BlockchainService.validasiKode(_kode.text);
    if (error != null) {
      setState(() => _pesan = error);
      return;
    }
    _setBusy(true);
    try {
      final alat = await _service.ambilAlat(_kode.text.trim());
      if (alat.diarsipkan) throw StateError('Alat arsip tidak dapat diubah.');
      if (!mounted) return;
      setState(() {
        _kodeDimuat = alat.kode;
        _nama.text = alat.nama;
        _deskripsi.text = alat.deskripsi;
        _pesan = 'Data dimuat. Ubah nama atau deskripsi lalu simpan.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _kodeDimuat = null;
          _pesan = BlockchainService.pesanErrorAman(error);
        });
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _kirim() async {
    if (_terkunci || !(_form.currentState?.validate() ?? false)) return;
    if (_kodeDimuat != _kode.text.trim()) {
      setState(() => _pesan = 'Muat data alat terlebih dahulu.');
      return;
    }
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

      final data = await _service.buatDataUbahAlat(
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
        _pesan = 'Setujui perubahan alat di MetaMask.';
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
            ? 'Alat ${_kode.text.trim()} berhasil diperbarui. '
                  'Kembali ke beranda untuk melihat daftar terbaru.'
            : 'Transaksi gagal di blockchain. Alat tidak diperbarui. '
                  'Periksa status alat dan hak admin.';
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
    _kodeDimuat = null;
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
                icon: Icons.edit_outlined,
                title: 'Edit alat',
                subtitle: 'Muat kode alat, ubah nama/deskripsi, lalu simpan.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _kode,
                onChanged: (_) => setState(() => _kodeDimuat = null),
                enabled: !_terkunci,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Kode alat',
                  hintText: 'ESP32-02',
                  helperText: 'Kode tetap; edit hanya nama dan deskripsi.',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
                validator: BlockchainService.validasiKode,
              ),
              TextButton.icon(
                onPressed: _terkunci ? null : _muatAlat,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Muat data alat'),
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
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Simpan melalui MetaMask'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
