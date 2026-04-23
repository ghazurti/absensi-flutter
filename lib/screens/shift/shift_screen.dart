import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/shift_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  final _api = ApiService();
  List<ShiftModel> _shifts = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.getShifts(
        bulan: _selectedMonth.month,
        tahun: _selectedMonth.year,
      );
      final List data = response.data;
      setState(() {
        _shifts = data.map((e) => ShiftModel.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat shift. Tarik untuk coba lagi.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddShift() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddShiftSheet(
        onSaved: _loadShifts,
        api: _api,
      ),
    );
  }

  Future<void> _deleteShift(ShiftModel shift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Shift'),
        content: Text('Hapus shift tanggal ${DateFormat('dd MMM yyyy').format(shift.tanggal)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.deleteShift(shift.id);
        _loadShifts();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift dihapus')));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Shift'),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
            setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
            _loadShifts();
          }),
          Center(child: Text(DateFormat('MMM yyyy').format(_selectedMonth), style: const TextStyle(color: Colors.white))),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
            setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
            _loadShifts();
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddShift,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Shift'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shifts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.schedule, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Belum ada shift', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _showAddShift, child: const Text('Tambah Shift')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadShifts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _shifts.length,
                    itemBuilder: (_, i) => _buildShiftCard(_shifts[i]),
                  ),
                ),
    );
  }

  Widget _buildShiftCard(ShiftModel shift) {
    final colors = {'pagi': Colors.orange, 'siang': Colors.blue, 'malam': Colors.indigo};
    final icons = {'pagi': Icons.wb_sunny, 'siang': Icons.wb_cloudy, 'malam': Icons.nightlight_round};
    final color = colors[shift.jenisShift] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icons[shift.jenisShift] ?? Icons.schedule, color: color),
        ),
        title: Text(DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(shift.tanggal)),
        subtitle: Text('${shift.labelShift} • ${shift.jamMasuk} - ${shift.jamKeluar}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _deleteShift(shift),
        ),
      ),
    );
  }
}

class _AddShiftSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final ApiService api;

  const _AddShiftSheet({required this.onSaved, required this.api});

  @override
  State<_AddShiftSheet> createState() => _AddShiftSheetState();
}

class _AddShiftSheetState extends State<_AddShiftSheet> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _tanggal;
  String _jenisShift = 'pagi';
  TimeOfDay _jamMasuk = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _jamKeluar = const TimeOfDay(hour: 14, minute: 0);
  bool _isSaving = false;

  final _shiftDefaults = {
    'pagi': {'masuk': const TimeOfDay(hour: 7, minute: 0), 'keluar': const TimeOfDay(hour: 14, minute: 0)},
    'siang': {'masuk': const TimeOfDay(hour: 14, minute: 0), 'keluar': const TimeOfDay(hour: 21, minute: 0)},
    'malam': {'masuk': const TimeOfDay(hour: 21, minute: 0), 'keluar': const TimeOfDay(hour: 7, minute: 0)},
  };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  Future<void> _save() async {
    if (_tanggal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih tanggal terlebih dahulu')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.api.createShift({
        'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal!),
        'jenis_shift': _jenisShift,
        'jam_masuk': '${_jamMasuk.hour.toString().padLeft(2, '0')}:${_jamMasuk.minute.toString().padLeft(2, '0')}',
        'jam_keluar': '${_jamKeluar.hour.toString().padLeft(2, '0')}:${_jamKeluar.minute.toString().padLeft(2, '0')}',
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      String msg = 'Terjadi kesalahan';
      if (e is DioException && e.response != null) {
        final data = e.response!.data;
        if (data is Map) msg = data['message']?.toString() ?? msg;
      }
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
          const Text('Tambah Shift', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(_tanggal == null ? 'Pilih Tanggal' : DateFormat('dd MMMM yyyy', 'id_ID').format(_tanggal!)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _jenisShift,
            decoration: const InputDecoration(labelText: 'Jenis Shift', border: OutlineInputBorder()),
            items: ['pagi', 'siang', 'malam'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
            onChanged: (v) {
              setState(() {
                _jenisShift = v!;
                _jamMasuk = _shiftDefaults[v]!['masuk'] as TimeOfDay;
                _jamKeluar = _shiftDefaults[v]!['keluar'] as TimeOfDay;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _jamMasuk);
                    if (t != null) setState(() => _jamMasuk = t);
                  },
                  child: Text('Masuk: ${_jamMasuk.format(context)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _jamKeluar);
                    if (t != null) setState(() => _jamKeluar = t);
                  },
                  child: Text('Keluar: ${_jamKeluar.format(context)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
            child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('SIMPAN SHIFT'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
