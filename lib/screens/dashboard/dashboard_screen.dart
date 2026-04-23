import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../absensi/absensi_screen.dart';
import '../shift/shift_screen.dart';
import '../izin/izin_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    _HomeTab(),
    AbsensiScreen(),
    ShiftScreen(),
    IzinScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.fingerprint), selectedIcon: Icon(Icons.fingerprint), label: 'Absensi'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'Shift'),
          NavigationDestination(icon: Icon(Icons.event_busy_outlined), selectedIcon: Icon(Icons.event_busy), label: 'Izin'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final response = await _api.getDashboard();
      setState(() {
        _dashboardData = response.data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Selamat Pagi' : now.hour < 17 ? 'Selamat Siang' : 'Selamat Malam';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF009540), Color(0xFF4CAF50)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(greeting,
                              style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(user?.name ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          Text(user?.jabatan ?? user?.unit ?? '',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(now),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_dashboardData != null) ...[
                      if (user?.isAdmin == true) ...[
                        _buildAdminStatsCard(),
                      ] else ...[
                        _buildAbsensiCard(),
                      ],
                      const SizedBox(height: 16),
                      _buildRekapCard(),
                    ],
                    const SizedBox(height: 16),
                    _buildMenuGrid(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminStatsCard() {
    final d = _dashboardData!;
    final stats = [
      {'label': 'Total Pegawai', 'value': d['total_pegawai']?.toString() ?? '0', 'color': Colors.blue, 'icon': Icons.people},
      {'label': 'Hadir Hari Ini', 'value': d['hadir_hari_ini']?.toString() ?? '0', 'color': Colors.green, 'icon': Icons.check_circle_outline},
      {'label': 'Terlambat', 'value': d['terlambat_hari_ini']?.toString() ?? '0', 'color': Colors.orange, 'icon': Icons.access_time},
      {'label': 'Belum Absen', 'value': d['belum_absen_hari_ini']?.toString() ?? '0', 'color': Colors.red, 'icon': Icons.person_off_outlined},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rekap Kehadiran Hari Ini',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: stats.map((s) {
                final color = s['color'] as Color;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(s['icon'] as IconData, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s['value'] as String,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: color)),
                            Text(s['label'] as String,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsensiCard() {
    final absensiHariIni = _dashboardData?['absensi_hari_ini'];
    final sudahCheckIn = absensiHariIni != null && absensiHariIni['check_in'] != null;
    final sudahCheckOut = absensiHariIni != null && absensiHariIni['check_out'] != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status Absensi Hari Ini',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusItem('Check In',
                    sudahCheckIn ? _formatJam(absensiHariIni['check_in']) : '--:--',
                    sudahCheckIn ? Colors.green : Colors.grey),
                const SizedBox(width: 24),
                _buildStatusItem('Check Out',
                    sudahCheckOut ? _formatJam(absensiHariIni['check_out']) : '--:--',
                    sudahCheckOut ? Colors.blue : Colors.grey),
                const Spacer(),
                if (absensiHariIni != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(absensiHariIni['status']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      absensiHariIni['status'].toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatJam(dynamic value) {
    if (value == null) return '--:--';
    try {
      final s = value.toString();
      final dt = (s.contains('Z') || s.contains('+'))
          ? DateTime.parse(s).toLocal()
          : DateTime.parse('${s}Z').toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '--:--';
    }
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      ],
    );
  }

  Widget _buildRekapCard() {
    final rekap = _dashboardData?['rekap_bulan'] as Map<String, dynamic>?;
    if (rekap == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rekap ${DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now())}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRekapItem('Hadir', rekap['hadir']?.toString() ?? '0', Colors.green),
                _buildRekapItem('Terlambat', rekap['terlambat']?.toString() ?? '0', Colors.orange),
                _buildRekapItem('Izin', rekap['izin']?.toString() ?? '0', Colors.blue),
                _buildRekapItem('Alpha', rekap['alpha']?.toString() ?? '0', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRekapItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    final menus = [
      {'icon': Icons.fingerprint, 'label': 'Absensi', 'color': Colors.blue, 'index': 1},
      {'icon': Icons.schedule, 'label': 'Input Shift', 'color': Colors.green, 'index': 2},
      {'icon': Icons.event_busy, 'label': 'Izin/Cuti', 'color': Colors.orange, 'index': 3},
      {'icon': Icons.bar_chart, 'label': 'Rekap', 'color': Colors.purple, 'index': 1},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: menus.length,
      itemBuilder: (context, i) {
        final menu = menus[i];
        return InkWell(
          onTap: () {
            final parent = context.findAncestorStateOfType<_DashboardScreenState>();
            parent?.setState(() => parent._selectedIndex = menu['index'] as int);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(menu['icon'] as IconData, color: menu['color'] as Color, size: 28),
                const SizedBox(height: 4),
                Text(menu['label'] as String, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'hadir': return Colors.green;
      case 'terlambat': return Colors.orange;
      case 'izin': return Colors.blue;
      case 'sakit': return Colors.purple;
      case 'alpha': return Colors.red;
      default: return Colors.grey;
    }
  }
}
