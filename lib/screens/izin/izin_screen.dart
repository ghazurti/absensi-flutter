import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class IzinScreen extends StatefulWidget {
  const IzinScreen({super.key});

  @override
  State<IzinScreen> createState() => _IzinScreenState();
}

class _IzinScreenState extends State<IzinScreen> {
  final _api = ApiService();
  List<dynamic> _izinList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIzin();
  }

  Future<void> _loadIzin() async {
    try {
      final response = await _api.getIzin();
      setState(() {
        _izinList = response.data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showTambahIzin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TambahIzinSheet(onSaved: _loadIzin, api: _api),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Izin / Cuti / Sakit')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTambahIzin,
        icon: const Icon(Icons.add),
        label: const Text('Ajukan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _izinList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Belum ada pengajuan izin', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _showTambahIzin, child: const Text('Ajukan Izin')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadIzin,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _izinList.length,
                    itemBuilder: (_, i) => _buildIzinCard(_izinList[i]),
                  ),
                ),
    );
  }

  Widget _buildIzinCard(Map<String, dynamic> izin) {
    final jenisColors = {'izin': Colors.blue, 'sakit': Colors.red, 'cuti': Colors.green};
    final color = jenisColors[izin['jenis']] ?? Colors.grey;
    final mulai = DateTime.tryParse(izin['tanggal_mulai'] ?? '') ?? DateTime.now();
    final selesai = DateTime.tryParse(izin['tanggal_selesai'] ?? '') ?? DateTime.now();
    final durasi = selesai.difference(mulai).inDays + 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                izin['jenis'].toString().toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('dd MMM').format(mulai)} - ${DateFormat('dd MMM yyyy').format(selesai)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('$durasi hari • ${izin['keterangan']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TambahIzinSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final ApiService api;

  const _TambahIzinSheet({required this.onSaved, required this.api});

  @override
  State<_TambahIzinSheet> createState() => _TambahIzinSheetState();
}

class _TambahIzinSheetState extends State<_TambahIzinSheet> {
  final _keteranganController = TextEditingController();
  String _jenis = 'izin';
  DateTime? _mulai;
  DateTime? _selesai;
  bool _isSaving = false;

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range != null) {
      setState(() {
        _mulai = range.start;
        _selesai = range.end;
      });
    }
  }

  Future<void> _save() async {
    if (_mulai == null || _selesai == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih tanggal terlebih dahulu')));
      return;
    }
    if (_keteranganController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keterangan tidak boleh kosong')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final formData = FormData.fromMap({
        'tanggal_mulai': DateFormat('yyyy-MM-dd').format(_mulai!),
        'tanggal_selesai': DateFormat('yyyy-MM-dd').format(_selesai!),
        'jenis': _jenis,
        'keterangan': _keteranganController.text,
      });
      await widget.api.createIzin(formData);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      String msg = 'Terjadi kesalahan';
      if (e is DioException && e.response != null) msg = e.response!.data['message'] ?? msg;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ajukan Izin/Cuti/Sakit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _jenis,
            decoration: const InputDecoration(labelText: 'Jenis', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'izin', child: Text('Izin')),
              DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
              DropdownMenuItem(value: 'cuti', child: Text('Cuti')),
            ],
            onChanged: (v) => setState(() => _jenis = v!),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range),
            label: Text(_mulai == null
                ? 'Pilih Rentang Tanggal'
                : '${DateFormat('dd MMM yyyy').format(_mulai!)} - ${DateFormat('dd MMM yyyy').format(_selesai!)}'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _keteranganController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Keterangan',
              border: OutlineInputBorder(),
              hintText: 'Jelaskan alasan izin...',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('AJUKAN'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
