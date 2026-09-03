import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../widgets/charts/custom_pie_chart.dart';
import '../widgets/charts/custom_bar_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  final DatabaseService databaseService;

  const AnalyticsScreen({
    super.key,
    required this.databaseService,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final expenses = databaseService.expenses;
    final totalSpending = databaseService.totalSpending;
    final categoryData = databaseService.categoryBreakdown;
    final barData = databaseService.getLast7DaysData();

    // Calculate top spending category
    ExpenseCategory? topCategory;
    double maxCategoryAmount = 0;
    categoryData.forEach((cat, amount) {
      if (amount > maxCategoryAmount) {
        maxCategoryAmount = amount;
        topCategory = cat;
      }
    });

    final ocrCount = expenses.where((e) => e.isOcrScanned).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống Kê & Báo Cáo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Tổng chi tiêu',
                    value: currencyFormatter.format(totalSpending),
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Chi nhiều nhất',
                    value: topCategory != null ? topCategory!.name : 'Chưa có',
                    icon: topCategory?.icon ?? Icons.star_rounded,
                    color: topCategory?.color ?? const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Tổng giao dịch',
                    value: '${expenses.length} khoản',
                    icon: Icons.receipt_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Quét từ OCR',
                    value: '$ocrCount hóa đơn',
                    icon: Icons.document_scanner_rounded,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Section 1: Animated Bar Chart (CustomPainter)
            Card(
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
                    const Row(
                      children: [
                        Icon(Icons.bar_chart_rounded, color: Color(0xFF3B82F6)),
                        SizedBox(width: 8),
                        Text(
                          'Chi tiêu 7 ngày qua (CustomPainter Bar Chart)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chạm vào từng cột để xem chi tiết số tiền chi tiêu',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBarChart(
                      data: barData,
                      height: 220,
                      primaryColor: const Color(0xFF3B82F6),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Section 2: Animated Pie Chart (CustomPainter)
            Card(
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
                    const Row(
                      children: [
                        Icon(Icons.pie_chart_rounded, color: Color(0xFF8B5CF6)),
                        SizedBox(width: 8),
                        Text(
                          'Cơ cấu chi theo danh mục (CustomPainter Pie Chart)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chạm vào từng lát cắt để xem chi tiết phần trăm & số tiền',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    AnimatedPieChart(
                      data: categoryData,
                      height: 240,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Section 3: Category breakdown progress list
            Card(
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
                    const Text(
                      'Chi tiết theo từng danh mục',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 14),
                    if (categoryData.isEmpty)
                      const Center(
                        child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...categoryData.entries.map((entry) {
                        final cat = entry.key;
                        final amount = entry.value;
                        final percentage = totalSpending > 0 ? (amount / totalSpending) : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(cat.icon, size: 16, color: cat.color),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter.format(amount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${(percentage * 100).toStringAsFixed(1)}%)',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage,
                                  backgroundColor: Colors.grey.shade100,
                                  valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
