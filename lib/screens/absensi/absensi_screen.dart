import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
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
        if (user?.isShift == true)
          _api.getShifts(bulan: now.month, tahun: now.year),
      ];

      final results = await Future.wait(futures);
      final List absensiData = results[0].data;
      final absensis = absensiData.map((e) => AbsensiModel.fromJson(e)).toList();
      final today = DateFormat('yyyy-MM-dd').format(now);

      List<ShiftModel> shifts = [];
      if (user?.isShift == true && results.length > 1) {
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
    final user = context.read<AuthProvider>().user;

    // User shift wajib pilih shift hari ini sebelum check-in
    if (isCheckIn && user?.isShift == true && _selectedShift == null) {
      _showError('Anda belum memiliki jadwal shift hari ini.\nTambahkan shift terlebih dahulu.');
      return;
    }

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

      final formMap = <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'foto': await MultipartFile.fromFile(foto.path, filename: 'foto.jpg'),
      };

      if (isCheckIn && _selectedShift != null) {
        formMap['shift_id'] = _selectedShift!.id;
      }

      final formData = FormData.fromMap(formMap);

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
            if (user?.isShift == true) ...[
              const SizedBox(height: 12),
              _buildShiftInfo(),
            ],
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

  Widget _buildShiftInfo() {
    if (_selectedShift != null) {
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
            Text(
              'Shift ${_selectedShift!.labelShift} • ${_selectedShift!.jamMasuk} - ${_selectedShift!.jamKeluar}',
              style: const TextStyle(color: Colors.blue, fontSize: 13),
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
