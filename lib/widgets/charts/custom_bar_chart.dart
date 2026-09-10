import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

class BarData {
  final String label;
  final double value;
  final DateTime date;

  BarData({required this.label, required this.value, required this.date});
}

class AnimatedBarChart extends StatefulWidget {
  final List<BarData> data;
  final double height;
  final Color primaryColor;
  final ValueChanged<BarData?>? onSelectionChanged;

  const AnimatedBarChart({
    super.key,
    required this.data,
    this.height = 220,
    this.primaryColor = const Color(0xFF3B82F6),
    this.onSelectionChanged,
  });

  @override
  State<AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<AnimatedBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedBarChart oldWidget) {
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
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
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

    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    );
    final maxValue = widget.data.map((d) => d.value).fold(0.0, max);
    final safeMax = maxValue > 0 ? maxValue * 1.15 : 100000.0;

    return Column(
      children: [
        if (_selectedIndex != null && _selectedIndex! < widget.data.length) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.primaryColor.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '${widget.data[_selectedIndex!].label}: ${currencyFormatter.format(widget.data[_selectedIndex!].value)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.primaryColor,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, widget.height);

              return GestureDetector(
                onTapDown: (details) {
                  final tapX = details.localPosition.dx;
                  final leftMargin = 38.0;
                  final rightMargin = 12.0;
                  final availableWidth = size.width - leftMargin - rightMargin;
                  final count = widget.data.length;
                  final slotWidth = availableWidth / count;

                  if (tapX >= leftMargin && tapX <= size.width - rightMargin) {
                    final tappedIndex =
                        ((tapX - leftMargin) / slotWidth).floor();
                    if (tappedIndex >= 0 && tappedIndex < count) {
                      setState(() {
                        _selectedIndex =
                            (_selectedIndex == tappedIndex)
                                ? null
                                : tappedIndex;
                      });
                      widget.onSelectionChanged?.call(
                        _selectedIndex == null
                            ? null
                            : widget.data[_selectedIndex!],
                      );
                    }
                  } else {
                    setState(() {
                      _selectedIndex = null;
                    });
                    widget.onSelectionChanged?.call(null);
                  }
                },
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: size,
                      painter: _BarChartPainter(
                        data: widget.data,
                        maxValue: safeMax,
                        animationProgress: _animation.value,
                        selectedIndex: _selectedIndex,
                        primaryColor: widget.primaryColor,
                        theme: Theme.of(context),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// CustomPainter rendering interactive animated bar chart
class _BarChartPainter extends CustomPainter {
  final List<BarData> data;
  final double maxValue;
  final double animationProgress;
  final int? selectedIndex;
  final Color primaryColor;
  final ThemeData theme;

  _BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.animationProgress,
    required this.selectedIndex,
    required this.primaryColor,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 40.0;
    const rightMargin = 12.0;
    const topMargin = 22.0;
    const bottomMargin = 28.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    if (chartWidth <= 0 || chartHeight <= 0 || data.isEmpty) return;

    // 1. Draw horizontal grid lines (4 lines)
    final compactFormatter = NumberFormat.compact(locale: 'vi_VN');
    final gridPaint =
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.18)
          ..strokeWidth = 1.0;

    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = topMargin + chartHeight - (i / gridLines) * chartHeight;
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        gridPaint,
      );

      // Y-axis labels
      final val = (maxValue / gridLines) * i;
      final textPainter = TextPainter(
        text: TextSpan(
          text: i == 0 ? '0' : compactFormatter.format(val),
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: leftMargin - 4);
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    // 2. Draw Bars & Labels
    final count = data.length;
    final slotWidth = chartWidth / count;
    final barWidth = min(slotWidth * 0.55, 28.0);

    for (int i = 0; i < count; i++) {
      final item = data[i];
      final isSelected = selectedIndex == i;

      final barCenterX = leftMargin + i * slotWidth + slotWidth / 2;
      final barHeight =
          (item.value / maxValue) * chartHeight * animationProgress;
      final barTop = topMargin + chartHeight - barHeight;
      final barRect = Rect.fromCenter(
        center: Offset(barCenterX, topMargin + chartHeight - barHeight / 2),
        width: barWidth,
        height: barHeight > 0 ? barHeight : 2,
      );

      final barRRect = RRect.fromRectAndCorners(
        barRect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
        bottomLeft: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      );

      // Gradient fill
      final fillPaint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors:
                  isSelected
                      ? [primaryColor, primaryColor.withValues(alpha: 0.7)]
                      : [
                        primaryColor.withValues(alpha: 0.85),
                        primaryColor.withValues(alpha: 0.35),
                      ],
            ).createShader(barRect);

      canvas.drawRRect(barRRect, fillPaint);

      // Selection indicator border
      if (isSelected) {
        final borderPaint =
            Paint()
              ..color = primaryColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0;
        canvas.drawRRect(barRRect, borderPaint);

        // Tooltip circle or pill above bar
        final tipPaint = Paint()..color = primaryColor;
        canvas.drawCircle(Offset(barCenterX, barTop - 6), 3.5, tipPaint);
      }

      // X-axis label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: item.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? primaryColor : Colors.grey.shade600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout(maxWidth: slotWidth);
      labelPainter.paint(
        canvas,
        Offset(
          barCenterX - labelPainter.width / 2,
          size.height - bottomMargin + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.data != data;
  }
}
