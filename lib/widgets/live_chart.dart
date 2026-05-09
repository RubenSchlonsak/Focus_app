import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ChartSeries {
  final String label;
  final Color color;
  final List<FlSpot> spots;

  const ChartSeries({
    required this.label,
    required this.color,
    required this.spots,
  });
}

class LiveChart extends StatelessWidget {
  final String title;
  final List<ChartSeries> series;
  final double minX;
  final double maxX;
  final double? minY;
  final double? maxY;
  final double height;

  const LiveChart({
    super.key,
    required this.title,
    required this.series,
    this.minX = 0,
    this.maxX = 1,
    this.minY,
    this.maxY,
    this.height = 180,
  });

  bool get _hasData => series.isNotEmpty && series.any((s) => s.spots.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 10),
            SizedBox(
              height: height,
              child: _hasData ? _buildChart() : _buildPlaceholder(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        for (final s in series)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14, height: 2.5, color: s.color),
                const SizedBox(width: 4),
                Text(s.label, style: TextStyle(color: s.color, fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChart() {
    final safeMaxX = (maxX > minX) ? maxX : minX + 1;
    return LineChart(
      LineChartData(
        minX: minX,
        maxX: safeMaxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        lineBarsData: series.map((s) {
          return LineChartBarData(
            spots: s.spots,
            isCurved: false,
            color: s.color,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, _) => Text(
                value.toStringAsFixed(1),
                style: const TextStyle(color: Colors.grey, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.white12),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Colors.white10, strokeWidth: 0.8),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        backgroundColor: Colors.transparent,
      ),
      duration: Duration.zero,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, color: Colors.white24, size: 32),
            SizedBox(height: 8),
            Text(
              'Stream aktivieren, um Daten zu sehen',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
