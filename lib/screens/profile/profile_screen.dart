import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../skor/skor_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF1565C0),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'P',
                      style: const TextStyle(fontSize: 34, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(user.jabatan ?? '',
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),

                  // Info Card
                  Card(
                    child: Column(
                      children: [
                        _buildInfoTile(Icons.badge, 'NIP', user.nip ?? '-'),
                        const Divider(height: 1),
                        _buildInfoTile(Icons.email, 'Email', user.email),
                        const Divider(height: 1),
                        _buildInfoTile(Icons.phone, 'No. HP', user.noHp ?? '-'),
                        const Divider(height: 1),
                        _buildInfoTile(Icons.business, 'Unit', user.unit ?? '-'),
                        const Divider(height: 1),
                        _buildInfoTile(Icons.admin_panel_settings, 'Role',
                            user.isAdmin ? 'Administrator' : 'Pegawai'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Menu Actions
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit, color: Color(0xFF1565C0)),
                          title: const Text('Edit Profil'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const EditProfilScreen())),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_outline, color: Color(0xFF1565C0)),
                          title: const Text('Ganti Password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const GantiPasswordScreen())),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.bar_chart, color: Colors.purple),
                          title: const Text('Skor Kehadiran'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const SkorScreen())),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined, color: Colors.orange),
                          title: const Text('Pengaturan Notifikasi'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const NotifikasiSettingScreen())),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logout
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Keluar'),
                          content: const Text('Yakin ingin keluar dari aplikasi?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Batal')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Keluar',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await context.read<AuthProvider>().logout();
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('KELUAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1565C0)),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(fontSize: 15, color: Colors.black87)),
    );
  }
}

// ─── Notifikasi Setting Screen ────────────────────────────────────────────────

class NotifikasiSettingScreen extends StatefulWidget {
  const NotifikasiSettingScreen({super.key});

  @override
  State<NotifikasiSettingScreen> createState() => _NotifikasiSettingScreenState();
}

class _NotifikasiSettingScreenState extends State<NotifikasiSettingScreen> {
  final _notif = NotificationService();
  bool _checkIn = true;
  bool _checkOut = true;
  int _jamCheckIn = 7;
  int _menitCheckIn = 30;
  int _jamCheckOut = 16;
  int _menitCheckOut = 30;

  Future<void> _simpan() async {
    await _notif.requestPermission();
    if (_checkIn) {
      await _notif.jadwalkanPengingatCheckIn(jam: _jamCheckIn, menit: _menitCheckIn);
    } else {
      await _notif.batalkanCheckIn();
    }
    if (_checkOut) {
      await _notif.jadwalkanPengingatCheckOut(jam: _jamCheckOut, menit: _menitCheckOut);
    } else {
      await _notif.batalkanCheckOut();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan notifikasi disimpan'),
            backgroundColor: Colors.green),
      );
    }
  }

  String _formatJam(int jam, int menit) =>
      '${jam.toString().padLeft(2, '0')}:${menit.toString().padLeft(2, '0')}';

  Future<void> _pilihWaktu(bool isCheckIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: isCheckIn ? _jamCheckIn : _jamCheckOut,
        minute: isCheckIn ? _menitCheckIn : _menitCheckOut,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _jamCheckIn = picked.hour;
          _menitCheckIn = picked.minute;
        } else {
          _jamCheckOut = picked.hour;
          _menitCheckOut = picked.minute;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Notifikasi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.login, color: Colors.green),
                    title: const Text('Pengingat Check-In'),
                    subtitle: Text('Setiap hari pukul ${_formatJam(_jamCheckIn, _menitCheckIn)}'),
                    value: _checkIn,
                    onChanged: (v) => setState(() => _checkIn = v),
                  ),
                  if (_checkIn) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.access_time, color: Colors.grey),
                      title: const Text('Jam pengingat check-in'),
                      trailing: TextButton(
                        onPressed: () => _pilihWaktu(true),
                        child: Text(_formatJam(_jamCheckIn, _menitCheckIn),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.logout, color: Colors.blue),
                    title: const Text('Pengingat Check-Out'),
                    subtitle: Text('Setiap hari pukul ${_formatJam(_jamCheckOut, _menitCheckOut)}'),
                    value: _checkOut,
                    onChanged: (v) => setState(() => _checkOut = v),
                  ),
                  if (_checkOut) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.access_time, color: Colors.grey),
                      title: const Text('Jam pengingat check-out'),
                      trailing: TextButton(
                        onPressed: () => _pilihWaktu(false),
                        child: Text(_formatJam(_jamCheckOut, _menitCheckOut),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notifikasi akan muncul setiap hari pada jam yang dipilih selama aplikasi terinstall.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _simpan,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan Pengaturan'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Profil Screen ───────────────────────────────────────────────────────

class EditProfilScreen extends StatefulWidget {
  const EditProfilScreen({super.key});

  @override
  State<EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<EditProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  bool _isLoading = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _noHpCtrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _noHpCtrl = TextEditingController(text: user?.noHp ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _noHpCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final formData = FormData.fromMap({
        'name': _nameCtrl.text,
        'email': _emailCtrl.text,
        'no_hp': _noHpCtrl.text,
      });

      await _api.updateProfile(formData);

      // Refresh user data
      if (mounted) {
        await context.read<AuthProvider>().refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email wajib diisi';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noHpCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'No. HP',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data jabatan, unit, dan NIP dikelola oleh admin kepegawaian.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan Perubahan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Ganti Password Screen ────────────────────────────────────────────────────

class GantiPasswordScreen extends StatefulWidget {
  const GantiPasswordScreen({super.key});

  @override
  State<GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<GantiPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  bool _isLoading = false;
  bool _showLama = false;
  bool _showBaru = false;
  bool _showKonfirmasi = false;

  final _lamaCtrl = TextEditingController();
  final _baruCtrl = TextEditingController();
  final _konfirmasiCtrl = TextEditingController();

  @override
  void dispose() {
    _lamaCtrl.dispose();
    _baruCtrl.dispose();
    _konfirmasiCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _api.gantiPassword(
        passwordLama: _lamaCtrl.text,
        password: _baruCtrl.text,
        passwordConfirmation: _konfirmasiCtrl.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password berhasil diubah'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Terjadi kesalahan. Coba lagi.';
        if (e is DioException && e.response != null) {
          final data = e.response!.data;
          if (data is Map) msg = data['message']?.toString() ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _lamaCtrl,
                obscureText: !_showLama,
                decoration: InputDecoration(
                  labelText: 'Password Lama',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_showLama ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showLama = !_showLama),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baruCtrl,
                obscureText: !_showBaru,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_showBaru ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showBaru = !_showBaru),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Wajib diisi';
                  if (v.length < 8) return 'Minimal 8 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _konfirmasiCtrl,
                obscureText: !_showKonfirmasi,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_showKonfirmasi ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showKonfirmasi = !_showKonfirmasi),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Wajib diisi';
                  if (v != _baruCtrl.text) return 'Password tidak sama';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
