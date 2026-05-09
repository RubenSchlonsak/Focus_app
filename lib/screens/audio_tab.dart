import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ble_service.dart';
import '../widgets/live_chart.dart';

class AudioTab extends StatelessWidget {
  const AudioTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (_, ble, _) {
        final samples = ble.audioSamples;
        final spots = [
          for (int i = 0; i < samples.length; i++)
            FlSpot(i.toDouble(), samples[i]),
        ];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LiveChart(
                title: 'AUDIO-WAVEFORM  (PCM Int16)',
                series: spots.isEmpty
                    ? []
                    : [
                        ChartSeries(
                          label: 'PCM',
                          color: const Color(0xFF00E5CC),
                          spots: spots,
                        ),
                      ],
                minX: 0,
                maxX: spots.isEmpty ? 512 : spots.last.x,
                minY: -32768,
                maxY: 32768,
                height: 220,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${samples.length} / 512 Samples',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  const Text(
                    '122 Samples/Paket',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  TextButton.icon(
                    onPressed: ble.clearAudioData,
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
