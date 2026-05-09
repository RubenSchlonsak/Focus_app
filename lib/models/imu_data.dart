import 'package:fl_chart/fl_chart.dart';

class ImuChartData {
  static const int maxSamples = 200;

  final List<FlSpot> ax = [];
  final List<FlSpot> ay = [];
  final List<FlSpot> az = [];
  final List<FlSpot> gx = [];
  final List<FlSpot> gy = [];
  final List<FlSpot> gz = [];

  int _idx = 0;

  void add({
    required double ax,
    required double ay,
    required double az,
    required double gx,
    required double gy,
    required double gz,
  }) {
    final x = _idx.toDouble();
    this.ax.add(FlSpot(x, ax));
    this.ay.add(FlSpot(x, ay));
    this.az.add(FlSpot(x, az));
    this.gx.add(FlSpot(x, gx));
    this.gy.add(FlSpot(x, gy));
    this.gz.add(FlSpot(x, gz));
    _idx++;
    if (this.ax.length > maxSamples) {
      this.ax.removeAt(0);
      this.ay.removeAt(0);
      this.az.removeAt(0);
      this.gx.removeAt(0);
      this.gy.removeAt(0);
      this.gz.removeAt(0);
    }
  }

  void clear() {
    ax.clear(); ay.clear(); az.clear();
    gx.clear(); gy.clear(); gz.clear();
    _idx = 0;
  }

  bool get isEmpty => ax.isEmpty;
  double get minX => ax.isEmpty ? 0 : ax.first.x;
  double get maxX => ax.isEmpty ? 1 : ax.last.x;
}
