import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/glass_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Simulated User Accounts
  final List<Map<String, dynamic>> _allUsers = [
    {
      'name': 'Sahan R',
      'email': 'sahan@example.com',
      'bills': 14,
      'docs': 3,
      'storage': 8.42,
      'lastBackup': '31 May 2026',
      'role': 'Admin',
    },
    {
      'name': 'Sahil Sharma',
      'email': 'sahil.sharma@example.com',
      'bills': 28,
      'docs': 8,
      'storage': 16.84,
      'lastBackup': '30 May 2026',
      'role': 'User',
    },
    {
      'name': 'Ananya Sen',
      'email': 'ananya.sen@example.com',
      'bills': 41,
      'docs': 12,
      'storage': 29.11,
      'lastBackup': '28 May 2026',
      'role': 'User',
    },
    {
      'name': 'Rohan Patel',
      'email': 'rohan.patel@example.com',
      'bills': 8,
      'docs': 2,
      'storage': 4.12,
      'lastBackup': '25 May 2026',
      'role': 'User',
    },
    {
      'name': 'Neha Gupta',
      'email': 'neha.gupta@example.com',
      'bills': 19,
      'docs': 5,
      'storage': 11.20,
      'lastBackup': '24 May 2026',
      'role': 'User',
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final isTablet = width > 600 && width <= 1024;

    final filteredUsers = _allUsers.where((u) {
      final query = _searchQuery.toLowerCase();
      return u['name'].toLowerCase().contains(query) ||
          u['email'].toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A), // Dark Background color #0F172A
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Sidebar Navigation for Desktop view
              if (isDesktop) _buildSidebarNav(),

              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Premium custom App Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.paddingM),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => context.pop(),
                                      child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'PlanSphere Admin Web',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                          letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'User Activity & Storage Infrastructure Control',
                                  style: TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8E44AD).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF8E44AD).withOpacity(0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFBB8FCE), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Platform Lead',
                                    style: TextStyle(color: Color(0xFFBB8FCE), fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Grid stats summary
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingM),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 1),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 2.1,
                        ),
                        delegate: SliverChildListDelegate([
                          _buildWebStatCard(
                            title: 'Total Users',
                            value: '2,842',
                            growth: '+14.8%',
                            icon: Icons.people_rounded,
                            color: AppColors.primary,
                          ),
                          _buildWebStatCard(
                            title: 'Cloud Storage Sizing',
                            value: '48.2 GB',
                            growth: 'Optimal',
                            icon: Icons.cloud_done_rounded,
                            color: AppColors.info,
                          ),
                          _buildWebStatCard(
                            title: 'Total Invoices Logs',
                            value: '18,421',
                            growth: '+8.4%',
                            icon: Icons.receipt_long_rounded,
                            color: AppColors.secondary,
                          ),
                          _buildWebStatCard(
                            title: 'Active Warranties',
                            value: '7,242',
                            growth: '+22.1%',
                            icon: Icons.verified_rounded,
                            color: AppColors.success,
                          ),
                        ]),
                      ),
                    ),

                    // Graphs & Category section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.paddingM),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User activity graph
                            Expanded(
                              flex: 3,
                              child: GlassCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Daily Active Users (DAUs)',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Simulated platform activity profiles over past 7 days',
                                        style: TextStyle(color: Colors.white30, fontSize: 11),
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        height: 180,
                                        child: LineChart(
                                          LineChartData(
                                            gridData: FlGridData(
                                              show: true,
                                              drawVerticalLine: false,
                                              getDrawingHorizontalLine: (v) => const FlLine(color: Colors.white10),
                                            ),
                                            titlesData: FlTitlesData(
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 32,
                                                  getTitlesWidget: (v, m) => Text(
                                                    '${v.toInt()}k',
                                                    style: const TextStyle(color: Colors.white30, fontSize: 9),
                                                  ),
                                                ),
                                              ),
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  getTitlesWidget: (v, m) {
                                                    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                                    if (v.toInt() >= 0 && v.toInt() < days.length) {
                                                      return Text(days[v.toInt()], style: const TextStyle(color: Colors.white30, fontSize: 9));
                                                    }
                                                    return const Text('');
                                                  },
                                                ),
                                              ),
                                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            ),
                                            borderData: FlBorderData(show: false),
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: const [
                                                  FlSpot(0, 1.2),
                                                  FlSpot(1, 1.5),
                                                  FlSpot(2, 1.4),
                                                  FlSpot(3, 1.8),
                                                  FlSpot(4, 2.2),
                                                  FlSpot(5, 2.0),
                                                  FlSpot(6, 2.4),
                                                ],
                                                isCurved: true,
                                                gradient: const LinearGradient(
                                                  colors: [AppColors.primary, AppColors.secondary],
                                                ),
                                                barWidth: 3,
                                                dotData: const FlDotData(show: true),
                                                belowBarData: BarAreaData(
                                                  show: true,
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      AppColors.primary.withOpacity(0.2),
                                                      AppColors.secondary.withOpacity(0.0),
                                                    ],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            if (isDesktop) ...[
                              const SizedBox(width: 16),
                              // Storage Metrics Breakdown
                              Expanded(
                                flex: 2,
                                child: GlassCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Platform Storage Allocation',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildStorageProgress(label: 'Invoice Images (JPG/PNG)', value: '31.2 GB (65%)', pct: 0.65, color: AppColors.primary),
                                        const SizedBox(height: 12),
                                        _buildStorageProgress(label: 'Invoice PDFs Documents', value: '14.1 GB (29%)', pct: 0.29, color: AppColors.accent),
                                        const SizedBox(height: 12),
                                        _buildStorageProgress(label: 'JSON Backups Metadata', value: '2.9 GB (6%)', pct: 0.06, color: AppColors.success),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // User Management Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('User Management Registry',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                SizedBox(
                                  width: 250,
                                  child: TextField(
                                  controller: _searchCtrl,
  
                                  decoration: const InputDecoration(
                                  hintText: 'Filter by name or email...',
                                  prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // User table listing
                            GlassCard(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                child: DataTable(
                                  columnSpacing: isDesktop ? 56 : 16,
                                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                  dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                  columns: const [
                                    DataColumn(label: Text('User Profile')),
                                    DataColumn(label: Text('Bills Logged')),
                                    DataColumn(label: Text('Storage (MB)')),
                                    DataColumn(label: Text('Last Cloud Backup')),
                                    DataColumn(label: Text('Role')),
                                  ],
                                  rows: filteredUsers.map((user) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                              Text(user['email'], style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text('${user['bills']}')),
                                        DataCell(Text('${user['storage'].toStringAsFixed(2)} MB')),
                                        DataCell(Text(user['lastBackup'])),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: user['role'] == 'Admin' ? Colors.purple.withOpacity(0.2) : Colors.white10,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              user['role'],
                                              style: TextStyle(
                                                color: user['role'] == 'Admin' ? Colors.purple[200] : Colors.white60,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 60)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarNav() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.8), // Translucent side nave
        border: const Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.security_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          const Text('Console Root', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
          const Text('platform_admin_sahan', style: TextStyle(color: Colors.white38, fontSize: 11)),
          const Divider(height: 40, color: Colors.white10),
          
          const _SidebarTile(icon: Icons.dashboard_rounded, title: 'Dashboard', isSelected: true),
          const _SidebarTile(icon: Icons.people_rounded, title: 'Registered Users', isSelected: false),
          const _SidebarTile(icon: Icons.storage_rounded, title: 'Cloud Buckets', isSelected: false),
          const _SidebarTile(icon: Icons.settings_rounded, title: 'API Controls', isSelected: false),
          
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Exit Web Panel', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
            onTap: () => context.pop(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWebStatCard({
    required String title,
    required String value,
    required String growth,
    required IconData icon,
    required Color color,
  }) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: growth == 'Optimal' ? AppColors.success.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          growth,
                          style: TextStyle(
                            color: growth == 'Optimal' ? AppColors.success : AppColors.primaryLight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageProgress({
    required String label,
    required String value,
    required double pct,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;

  const _SidebarTile({required this.icon, required this.title, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.12) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppColors.primaryLight : Colors.white60, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        ),
        minLeadingWidth: 20,
      ),
    );
  }
}
