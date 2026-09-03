import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../widgets/expense_card.dart';
import '../widgets/charts/custom_bar_chart.dart';
import 'camera_viewfinder_screen.dart';
import 'add_expense_screen.dart';
import 'expense_list_screen.dart';
import 'analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  final DatabaseService databaseService;

  const HomeScreen({
    super.key,
    required this.databaseService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.databaseService,
      builder: (context, _) {
        final screens = [
          _buildDashboardTab(context),
          ExpenseListScreen(databaseService: widget.databaseService),
          AnalyticsScreen(databaseService: widget.databaseService),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Tổng quan',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Sổ chi tiêu',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart_outline_rounded),
                selectedIcon: Icon(Icons.pie_chart_rounded),
                label: 'Thống kê',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openScanReceiptScreen(context),
            icon: const Icon(Icons.document_scanner_rounded),
            label: const Text('Quét Hóa Đơn (OCR)', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildDashboardTab(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final totalSpending = widget.databaseService.totalSpending;
    final recentExpenses = widget.databaseService.expenses.take(4).toList();
    final barData = widget.databaseService.getLast7DaysData();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Quản Lý Chi Tiêu OCR', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Thêm thủ công',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddExpenseScreen(databaseService: widget.databaseService),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => widget.databaseService.init(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Balance Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tổng chi tiêu toàn bộ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'AI On-Device',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      currencyFormatter.format(totalSpending),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Quick stats pill row
                    Row(
                      children: [
                        _buildHeroSubStat(
                          icon: Icons.receipt_rounded,
                          label: 'Giao dịch',
                          value: '${widget.databaseService.expenses.length}',
                        ),
                        const SizedBox(width: 16),
                        _buildHeroSubStat(
                          icon: Icons.document_scanner_rounded,
                          label: 'OCR Bills',
                          value: '${widget.databaseService.expenses.where((e) => e.isOcrScanned).length}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.document_scanner_rounded,
                        label: 'Quét Hóa Đơn',
                        color: const Color(0xFF6366F1),
                        onTap: () => _openScanReceiptScreen(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.edit_note_rounded,
                        label: 'Thêm Thủ Công',
                        color: const Color(0xFF10B981),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddExpenseScreen(databaseService: widget.databaseService),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.insights_rounded,
                        label: 'Xem Báo Cáo',
                        color: const Color(0xFFF59E0B),
                        onTap: () {
                          setState(() {
                            _currentIndex = 2; // Switch to analytics tab
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // CustomPainter Bar Chart Preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Chi tiêu tuần này',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _currentIndex = 2;
                                });
                              },
                              child: const Text('Xem biểu đồ tròn'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AnimatedBarChart(
                          data: barData,
                          height: 180,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Recent Transactions Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Giao dịch gần đây',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentIndex = 1; // Switch to full list
                        });
                      },
                      child: const Text('Xem tất cả'),
                    ),
                  ],
                ),
              ),

              // Recent Transactions List
              if (recentExpenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('Chưa có chi tiêu nào. Hãy quét hóa đơn đầu tiên!'),
                  ),
                )
              else
                ...recentExpenses.map((expense) {
                  return ExpenseCard(
                    expense: expense,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(
                            databaseService: widget.databaseService,
                            initialExpense: expense,
                          ),
                        ),
                      );
                    },
                    onDelete: () {
                      widget.databaseService.deleteExpense(expense.id);
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSubStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _openScanReceiptScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraViewfinderScreen(databaseService: widget.databaseService),
      ),
    );
  }
}
