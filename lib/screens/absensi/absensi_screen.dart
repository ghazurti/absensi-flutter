import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/device_service.dart';
import '../../models/absensi_model.dart';
import '../../models/shift_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({super.key});

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> {
  final _api = ApiService();
  AbsensiModel? _absensiHariIni;
  List<AbsensiModel> _riwayat = [];
  ShiftModel? _selectedShift;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final user = context.read<AuthProvider>().user;

      final futures = <Future>[
        _api.getAbsensi(bulan: now.month, tahun: now.year),
        if (user?.canManageShift == true)
          _api.getShifts(bulan: now.month, tahun: now.year),
      ];

      final results = await Future.wait(futures);
      final List absensiData = results[0].data;
      final absensis = absensiData.map((e) => AbsensiModel.fromJson(e)).toList();
      final today = DateFormat('yyyy-MM-dd').format(now);

      List<ShiftModel> shifts = [];
      if (user?.canManageShift == true && results.length > 1) {
        final List shiftData = results[1].data;
        shifts = shiftData.map((e) => ShiftModel.fromJson(e)).toList();
      }

      setState(() {
        _absensiHariIni = absensis.where((a) =>
            DateFormat('yyyy-MM-dd').format(a.tanggal) == today).firstOrNull;
        _riwayat = absensis;
        _selectedShift = shifts.where((s) =>
            DateFormat('yyyy-MM-dd').format(s.tanggal) == today).firstOrNull;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String msg = 'Gagal memuat data. Tarik untuk coba lagi.';
        if (e is DioException && e.response != null) {
          msg = e.response!.data?['message'] ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Position?> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('GPS tidak aktif. Aktifkan GPS terlebih dahulu.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Izin lokasi ditolak.');
        return null;
      }
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  // Placeholder JPEG valid (1x1 px, 134 byte) saat kamera dinonaktifkan
  static const String _placeholderFotoBase64 =
      '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

  Future<XFile?> _ambilFoto() async {
    final picker = ImagePicker();
    return await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.front,
    );
  }

  Future<void> _doAbsensi(bool isCheckIn) async {
    final user = context.read<AuthProvider>().user;

    final isWeekend = [DateTime.saturday, DateTime.sunday].contains(DateTime.now().weekday);
    if (isCheckIn && user?.isShift == true && user?.isItUnit != true && _selectedShift == null) {
      _showError('Anda belum memiliki jadwal shift hari ini.\nTambahkan shift terlebih dahulu.');
      return;
    }
    if (isCheckIn && user?.isItUnit == true && isWeekend && _selectedShift == null) {
      _showError('Hari ini akhir pekan (Sabtu/Minggu).\nKhusus IT/SIMRS yang bertugas On-Call / Shift, silakan tambahkan jadwal di tab Shift terlebih dahulu.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. Cek keamanan perangkat (Developer Mode, Emulator, Root, Jam Otomatis, Fake GPS app)
      final security = await DeviceService.checkSecurity();
      if (security.blockingReason != null) {
        _showError(security.blockingReason!);
        setState(() => _isProcessing = false);
        return;
      }

      // 2. Ambil koordinat GPS segar
      final position = await _getLocation();
      if (position == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // 3. Cek Fake GPS (Mock Location) — kirim laporan ke server agar tercatat di Audit Log
      if (position.isMocked) {
        try {
          final reportData = FormData.fromMap({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'is_mocked': 1,
            'accuracy': position.accuracy,
          });
          if (isCheckIn) {
            await _api.checkIn(reportData);
          } else {
            await _api.checkOut(reportData);
          }
        } catch (_) {}
        _showError('Lokasi palsu (Fake GPS) terdeteksi!\nAbsensi ditolak dan percobaan ini dicatat oleh sistem.');
        setState(() => _isProcessing = false);
        return;
      }

      // 4. Cek akurasi GPS (hindari lokasi kasar/seluler > 100m) & lokasi basi (> 60 detik)
      if (position.accuracy > 100) {
        _showError('Sinyal GPS kurang akurat (${position.accuracy.round()} m).\nPindah ke area lebih terbuka lalu coba lagi.');
        setState(() => _isProcessing = false);
        return;
      }
      if (DateTime.now().difference(position.timestamp).inSeconds.abs() > 60) {
        _showError('Data lokasi GPS sudah kedaluwarsa.\nTunggu beberapa detik lalu coba lagi.');
        setState(() => _isProcessing = false);
        return;
      }

      final jarak = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        AppConstants.rsudLatitude,
        AppConstants.rsudLongitude,
      );

      if (jarak > AppConstants.radiusAbsensi) {
        _showError('Anda berada di luar area RSUD.\nJarak: ${jarak.round()} meter');
        setState(() => _isProcessing = false);
        return;
      }

      final formMap = <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'is_mocked': position.isMocked ? 1 : 0,
        'accuracy': position.accuracy,
      };

      if (AppConstants.enableCameraAbsensi) {
        final foto = await _ambilFoto();
        if (foto == null) {
          setState(() => _isProcessing = false);
          return;
        }
        formMap['foto'] =
            await MultipartFile.fromFile(foto.path, filename: 'foto.jpg');
      } else {
        formMap['foto'] = MultipartFile.fromBytes(
          base64Decode(_placeholderFotoBase64),
          filename: 'foto.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        );
      }

      if (isCheckIn && _selectedShift != null) {
        formMap['shift_id'] = _selectedShift!.id;
      }

      final formData = FormData.fromMap(formMap);

      if (isCheckIn) {
        await _api.checkIn(formData);
        _showSuccess('Absen masuk berhasil!');
      } else {
        await _api.checkOut(formData);
        _showSuccess('Absen pulang berhasil!');
      }

      await _loadData();
    } catch (e) {
      String msg = 'Terjadi kesalahan';
      if (e is DioException && e.response != null) {
        final data = e.response!.data;
        if (data is Map) msg = data['message']?.toString() ?? msg;
      }
      _showError(msg);
    }

    setState(() => _isProcessing = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Absensi')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAbsensiCard(),
                    const SizedBox(height: 24),
                    const Text('Riwayat Absensi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ..._riwayat.map(_buildRiwayatItem),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAbsensiCard() {
    final sudahCheckIn = _absensiHariIni?.sudahCheckIn ?? false;
    final sudahCheckOut = _absensiHariIni?.sudahCheckOut ?? false;
    final user = context.read<AuthProvider>().user;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Absensi Hari Ini',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now()),
                style: const TextStyle(color: Colors.grey)),
            if (user?.canManageShift == true) ...[
              const SizedBox(height: 12),
              _buildShiftInfo(),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Absen Masuk',
                    sudahCheckIn
                        ? DateFormat('HH:mm').format(_absensiHariIni!.checkIn!)
                        : '--:--',
                    sudahCheckIn ? Colors.green : Colors.grey,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.grey[300]),
                Expanded(
                  child: _buildTimeInfo(
                    'Absen Pulang',
                    sudahCheckOut
                        ? DateFormat('HH:mm').format(_absensiHariIni!.checkOut!)
                        : '--:--',
                    sudahCheckOut ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isProcessing)
              const CircularProgressIndicator()
            else if (!sudahCheckIn)
              ElevatedButton.icon(
                onPressed: () => _doAbsensi(true),
                icon: const Icon(Icons.login),
                label: const Text('ABSEN MASUK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              )
            else if (!sudahCheckOut)
              ElevatedButton.icon(
                onPressed: () => _doAbsensi(false),
                icon: const Icon(Icons.logout),
                label: const Text('ABSEN PULANG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Absensi hari ini selesai', style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftInfo() {
    final user = context.read<AuthProvider>().user;
    if (_selectedShift != null) {
      final ket = (_selectedShift!.keterangan ?? '').trim();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Shift ${_selectedShift!.labelShift} • ${_selectedShift!.jamMasuk} - ${_selectedShift!.jamKeluar}${ket.isNotEmpty ? ' ($ket)' : ''}',
                style: const TextStyle(color: Colors.blue, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (user?.isItUnit == true && user?.isShift != true) {
      final isWeekend = [DateTime.saturday, DateTime.sunday].contains(DateTime.now().weekday);
      final isFriday = DateTime.now().weekday == DateTime.friday;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isWeekend ? Colors.orange[50] : Colors.green[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isWeekend ? Colors.orange[200]! : Colors.green[200]!),
        ),
        child: Row(
          children: [
            Icon(
              isWeekend ? Icons.info_outline : Icons.computer,
              size: 16,
              color: isWeekend ? Colors.orange : Colors.green[700],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isWeekend
                    ? 'Akhir pekan (Libur). Jika Anda piket On-Call / Shift IT hari ini, tambahkan di tab Shift.'
                    : 'Jam Reguler IT (${isFriday ? '07:30 - 16:30' : '07:30 - 16:00'}). Jika hari ini Shift Siang (14:00 - 21:00), tambahkan di tab Shift.',
                style: TextStyle(
                  color: isWeekend ? Colors.orange[800] : Colors.green[800],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Belum ada jadwal shift hari ini. Tambahkan di tab Shift.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(time, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildRiwayatItem(AbsensiModel absensi) {
    final statusColor = {
      'hadir': Colors.green,
      'terlambat': Colors.orange,
      'izin': Colors.blue,
      'sakit': Colors.purple,
      'alpha': Colors.red,
    }[absensi.status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              DateFormat('dd').format(absensi.tanggal),
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ),
        title: Text(DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(absensi.tanggal)),
        subtitle: Text(
          '${absensi.checkIn != null ? DateFormat('HH:mm').format(absensi.checkIn!) : '--:--'} - ${absensi.checkOut != null ? DateFormat('HH:mm').format(absensi.checkOut!) : '--:--'}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            absensi.status.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      ),
    );
  }
}
