import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../models/category.dart';

class PieSliceData {
  final ExpenseCategory category;
  final double amount;
  final double percentage;

  PieSliceData({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

class AnimatedPieChart extends StatefulWidget {
  final Map<ExpenseCategory, double> data;
  final double height;

  const AnimatedPieChart({
    super.key,
    required this.data,
    this.height = 240,
  });

  @override
  State<AnimatedPieChart> createState() => _AnimatedPieChartState();
}

class _AnimatedPieChartState extends State<AnimatedPieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final totalAmount = widget.data.values.fold(0.0, (sum, val) => sum + val);

    if (totalAmount <= 0) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Chưa có dữ liệu chi tiêu',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final slices = widget.data.entries.map((e) {
      return PieSliceData(
        category: e.key,
        amount: e.value,
        percentage: (e.value / totalAmount) * 100,
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, widget.height);
              final center = Offset(size.width / 2, size.height / 2);
              final radius = min(size.width, size.height) * 0.42;
              final holeRadius = radius * 0.58;

              return GestureDetector(
                onTapDown: (details) {
                  final touch = details.localPosition;
                  final dx = touch.dx - center.dx;
                  final dy = touch.dy - center.dy;
                  final distance = sqrt(dx * dx + dy * dy);

                  if (distance >= holeRadius && distance <= radius + 15) {
                    // Touch within donut ring
                    double angle = atan2(dy, dx);
                    if (angle < 0) angle += 2 * pi;
                    // Start angle offset is -pi / 2
                    angle = (angle + pi / 2) % (2 * pi);

                    double currentAngle = 0.0;
                    int? foundIndex;
                    for (int i = 0; i < slices.length; i++) {
                      final sweep = (slices[i].amount / totalAmount) * 2 * pi;
                      if (angle >= currentAngle && angle <= currentAngle + sweep) {
                        foundIndex = i;
                        break;
                      }
                      currentAngle += sweep;
                    }

                    setState(() {
                      _selectedIndex = (_selectedIndex == foundIndex) ? null : foundIndex;
                    });
                  } else if (distance < holeRadius) {
                    setState(() {
                      _selectedIndex = null;
                    });
                  }
                },
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: size,
                      painter: _PieChartPainter(
                        slices: slices,
                        totalAmount: totalAmount,
                        animationProgress: _animation.value,
                        selectedIndex: _selectedIndex,
                        theme: Theme.of(context),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Selected Slice Detail Badge
        if (_selectedIndex != null && _selectedIndex! < slices.length) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: slices[_selectedIndex!].category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: slices[_selectedIndex!].category.color,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  slices[_selectedIndex!].category.icon,
                  size: 18,
                  color: slices[_selectedIndex!].category.color,
                ),
                const SizedBox(width: 8),
                Text(
                  '${slices[_selectedIndex!].category.name}: ${currencyFormatter.format(slices[_selectedIndex!].amount)} (${slices[_selectedIndex!].percentage.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: slices[_selectedIndex!].category.color,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(slices.length, (index) {
            final slice = slices[index];
            final isSelected = _selectedIndex == index;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedIndex = isSelected ? null : index;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? slice.category.color.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: slice.category.color, width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: slice.category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      slice.category.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${slice.percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// CustomPainter rendering interactive animated donut pie chart
class _PieChartPainter extends CustomPainter {
  final List<PieSliceData> slices;
  final double totalAmount;
  final double animationProgress;
  final int? selectedIndex;
  final ThemeData theme;

  _PieChartPainter({
    required this.slices,
    required this.totalAmount,
    required this.animationProgress,
    required this.selectedIndex,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty || totalAmount <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) * 0.42;
    final holeRadius = baseRadius * 0.58;

    double startAngle = -pi / 2; // Start from 12 o'clock

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final isSelected = selectedIndex == i;
      final sweepAngle = (slice.amount / totalAmount) * 2 * pi * animationProgress;

      final radius = isSelected ? baseRadius + 7 : baseRadius;
      final currentHoleRadius = isSelected ? holeRadius - 2 : holeRadius;
      final strokeWidth = radius - currentHoleRadius;

      final paint = Paint()
        ..color = slice.category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true;

      final arcRect = Rect.fromCircle(
        center: center,
        radius: (radius + currentHoleRadius) / 2,
      );

      canvas.drawArc(
        arcRect,
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      // White divider between slices
      if (slices.length > 1) {
        final dividerPaint = Paint()
          ..color = theme.scaffoldBackgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        final dividerAngle = startAngle;
        final p1 = Offset(
          center.dx + currentHoleRadius * cos(dividerAngle),
          center.dy + currentHoleRadius * sin(dividerAngle),
        );
        final p2 = Offset(
          center.dx + (radius + 1) * cos(dividerAngle),
          center.dy + (radius + 1) * sin(dividerAngle),
        );
        canvas.drawLine(p1, p2, dividerPaint);
      }

      startAngle += sweepAngle;
    }

    // Center Summary Text
    final currencyFormatter = NumberFormat.compactCurrency(locale: 'vi_VN', symbol: 'đ');
    final titleText = selectedIndex != null && selectedIndex! < slices.length
        ? slices[selectedIndex!].category.name
        : 'Tổng chi';
    final amountText = selectedIndex != null && selectedIndex! < slices.length
        ? currencyFormatter.format(slices[selectedIndex!].amount)
        : currencyFormatter.format(totalAmount);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: '$titleText\n',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(
            text: amountText,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    titlePainter.layout(maxWidth: holeRadius * 1.8);
    titlePainter.paint(
      canvas,
      Offset(center.dx - titlePainter.width / 2, center.dy - titlePainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.slices != slices;
  }
}
