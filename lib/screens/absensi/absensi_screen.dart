import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/absensi_model.dart';
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
      final response = await _api.getAbsensi(bulan: now.month, tahun: now.year);
      final List data = response.data;
      final absensis = data.map((e) => AbsensiModel.fromJson(e)).toList();
      final today = DateFormat('yyyy-MM-dd').format(now);
      setState(() {
        _absensiHariIni = absensis.where((a) =>
            DateFormat('yyyy-MM-dd').format(a.tanggal) == today).firstOrNull;
        _riwayat = absensis;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat data. Tarik untuk coba lagi.'),
              backgroundColor: Colors.red),
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
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<XFile?> _ambilFoto() async {
    final picker = ImagePicker();
    return await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.front,
    );
  }

  Future<void> _doAbsensi(bool isCheckIn) async {
    setState(() => _isProcessing = true);

    try {
      final position = await _getLocation();
      if (position == null) {
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

      final foto = await _ambilFoto();
      if (foto == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final formData = FormData.fromMap({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'foto': await MultipartFile.fromFile(foto.path, filename: 'foto.jpg'),
      });

      if (isCheckIn) {
        await _api.checkIn(formData);
        _showSuccess('Check-in berhasil!');
      } else {
        await _api.checkOut(formData);
        _showSuccess('Check-out berhasil!');
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Check In',
                    sudahCheckIn
                        ? DateFormat('HH:mm').format(_absensiHariIni!.checkIn!)
                        : '--:--',
                    sudahCheckIn ? Colors.green : Colors.grey,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.grey[300]),
                Expanded(
                  child: _buildTimeInfo(
                    'Check Out',
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
                label: const Text('CHECK IN SEKARANG'),
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
                label: const Text('CHECK OUT SEKARANG'),
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
