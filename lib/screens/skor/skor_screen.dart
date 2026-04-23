import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class SkorScreen extends StatefulWidget {
  const SkorScreen({super.key});

  @override
  State<SkorScreen> createState() => _SkorScreenState();
}

class _SkorScreenState extends State<SkorScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  int _bulan = DateTime.now().month;
  int _tahun = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadSkor();
  }

  Future<void> _loadSkor() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getSkor(bulan: _bulan, tahun: _tahun);
      setState(() {
        _data = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat skor. Tarik untuk coba lagi.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skor Kehadiran'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _data == null
                    ? const Center(child: Text('Gagal memuat data'))
                    : RefreshIndicator(
                        onRefresh: _loadSkor,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildSkorCard(),
                              const SizedBox(height: 12),
                              _buildRekapCard(),
                              const SizedBox(height: 12),
                              _buildDetailCard(),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final months = List.generate(12, (i) =>
        DateFormat('MMMM', 'id_ID').format(DateTime(0, i + 1)));
    final years = List.generate(3, (i) => DateTime.now().year - i);

    return Container(
      color: AppConstants.primaryColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _bulan,
              dropdownColor: Colors.white,
              decoration: _dropdownDecoration('Bulan'),
              style: const TextStyle(color: Colors.black, fontSize: 13),
              items: List.generate(12, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(months[i]),
              )),
              onChanged: (v) {
                if (v != null) setState(() => _bulan = v);
                _loadSkor();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _tahun,
              dropdownColor: Colors.white,
              decoration: _dropdownDecoration('Tahun'),
              style: const TextStyle(color: Colors.black, fontSize: 13),
              items: years.map((y) => DropdownMenuItem(
                value: y,
                child: Text(y.toString()),
              )).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _tahun = v);
                _loadSkor();
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }

  Widget _buildSkorCard() {
    final skor = (_data?['skor_akhir'] as num?)?.toDouble() ?? 0;
    final potongan = (_data?['total_potongan'] as num?)?.toDouble() ?? 0;

    Color skorColor;
    String skorLabel;
    if (skor >= 90) {
      skorColor = Colors.green;
      skorLabel = 'Sangat Baik';
    } else if (skor >= 75) {
      skorColor = Colors.blue;
      skorLabel = 'Baik';
    } else if (skor >= 60) {
      skorColor = Colors.orange;
      skorLabel = 'Cukup';
    } else {
      skorColor = Colors.red;
      skorLabel = 'Kurang';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _data?['periode']?['label'] ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: skorColor, width: 8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    skor.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: skorColor,
                    ),
                  ),
                  Text('/ 100', style: TextStyle(color: skorColor, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(skorLabel,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: skorColor)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSkorItem('Skor Awal', '100.00', Colors.grey),
                const SizedBox(width: 8),
                const Icon(Icons.remove, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                _buildSkorItem('Potongan', potongan.toStringAsFixed(2), Colors.red),
                const SizedBox(width: 8),
                const Icon(Icons.drag_handle, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                _buildSkorItem('Skor Akhir', skor.toStringAsFixed(2), skorColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkorItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildRekapCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Hadir', _data?['total_hadir']?.toString() ?? '0', Colors.green),
            _buildStatItem('Alpha', _data?['total_alpha']?.toString() ?? '0', Colors.red),
            _buildStatItem('Izin', _data?['total_izin']?.toString() ?? '0', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildDetailCard() {
    final detail = _data?['detail'] as Map<String, dynamic>?;
    if (detail == null) return const SizedBox.shrink();

    final kriteria = [
      {'kode': 'KT1', 'label': 'Terlambat 1–30 menit'},
      {'kode': 'KT2', 'label': 'Terlambat 31–60 menit'},
      {'kode': 'KT3', 'label': 'Terlambat 61–90 menit'},
      {'kode': 'KT4', 'label': 'Terlambat >90 menit'},
      {'kode': 'KT5', 'label': 'Tidak check-out'},
      {'kode': 'KT6', 'label': 'Alpha / tidak hadir'},
    ];

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Detail Potongan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Divider(height: 1),
          ...kriteria.map((k) {
            final kode = k['kode']!;
            final d = detail[kode] as Map<String, dynamic>?;
            final kali = d?['kali'] ?? 0;
            final jumlah = (d?['jumlah'] as num?)?.toDouble() ?? 0;
            final persen = d?['persen'] ?? 0;
            final hasValue = kali > 0;

            return Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasValue ? Colors.red[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(kode,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: hasValue ? Colors.red : Colors.grey,
                        )),
                  ),
                  title: Text(k['label']!, style: const TextStyle(fontSize: 13)),
                  subtitle: Text('${persen}% × $kali kali',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: Text(
                    jumlah > 0 ? '-${jumlah.toStringAsFixed(2)}' : '0',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasValue ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}
