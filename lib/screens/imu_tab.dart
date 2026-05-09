import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ble_service.dart';
import '../widgets/live_chart.dart';

class ImuTab extends StatelessWidget {
  const ImuTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (_, ble, _) {
        final d = ble.imuChartData;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LiveChart(
                title: 'BESCHLEUNIGUNG (g)',
                series: d.isEmpty
                    ? []
                    : [
                        ChartSeries(label: 'X', color: Colors.redAccent,   spots: d.ax),
                        ChartSeries(label: 'Y', color: Colors.greenAccent, spots: d.ay),
                        ChartSeries(label: 'Z', color: Colors.blueAccent,  spots: d.az),
                      ],
                minX: d.minX,
                maxX: d.maxX,
                minY: -4,
                maxY: 4,
              ),
              const SizedBox(height: 12),
              LiveChart(
                title: 'GYROSKOP (dps)',
                series: d.isEmpty
                    ? []
                    : [
                        ChartSeries(label: 'X', color: Colors.orangeAccent, spots: d.gx),
                        ChartSeries(label: 'Y', color: Colors.yellowAccent, spots: d.gy),
                        ChartSeries(label: 'Z', color: Colors.purpleAccent, spots: d.gz),
                      ],
                minX: d.minX,
                maxX: d.maxX,
                minY: -600,
                maxY: 600,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${d.ax.length} Samples im Puffer',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  TextButton.icon(
                    onPressed: ble.clearImuData,
                    icon: const Icon(Icons.clear_all, size: 14),
                    label: const Text('Leeren'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
