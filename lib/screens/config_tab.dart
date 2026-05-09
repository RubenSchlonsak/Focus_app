import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble/ble_constants.dart';
import '../services/ble_service.dart';

class ConfigTab extends StatefulWidget {
  const ConfigTab({super.key});

  @override
  State<ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<ConfigTab> {
  // Local mirrors of device config — kept in sync with STATUS notifications
  int _audioGain    = 40;
  int _audioRateIdx = 0;
  int _imuRateIdx   = 2;
  int _accelIdx     = 0;
  int _gyroIdx      = 2;
  Object? _lastStatus; // identity sentinel — re-sync whenever STATUS changes

  void _syncFromStatus(BleService ble) {
    final s = ble.status;
    if (s == null || identical(s, _lastStatus)) return;
    _lastStatus   = s;
    _audioGain    = s.audioGain;
    _audioRateIdx = s.audioRateIdx;
    _imuRateIdx   = s.imuRateIdx;
    _accelIdx     = s.accelIdx;
    _gyroIdx      = s.gyroIdx;
  }

  void _send(BleService ble, int id, int val) {
    ble.sendCfg(id, val);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CFG 0x${id.toRadixString(16).toUpperCase()} = $val gesendet'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sendAll(BleService ble) {
    ble.sendCfg(BleConstants.cfgAudioGain,  _audioGain);
    ble.sendCfg(BleConstants.cfgAudioRate,  _audioRateIdx);
    ble.sendCfg(BleConstants.cfgImuRate,    _imuRateIdx);
    ble.sendCfg(BleConstants.cfgAccelRange, _accelIdx);
    ble.sendCfg(BleConstants.cfgGyroRange,  _gyroIdx);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alle Einstellungen gesendet'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (_, ble, _) {
        _syncFromStatus(ble);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Audio ──────────────────────────────────────────────────
              _SectionHeader('Audio'),
              const SizedBox(height: 8),
              _GainCard(
                gain: _audioGain,
                onChanged: (v) => setState(() => _audioGain = v),
                onChangeEnd: (v) => _send(ble, BleConstants.cfgAudioGain, v),
              ),
              const SizedBox(height: 10),
              _DropdownCard(
                title: 'Audio-Samplerate',
                options: BleConstants.audioRates,
                value: _audioRateIdx.clamp(0, BleConstants.audioRates.length - 1),
                onChanged: (v) => setState(() => _audioRateIdx = v),
                onSend: () => _send(ble, BleConstants.cfgAudioRate, _audioRateIdx),
              ),
              const SizedBox(height: 20),
              // ── IMU ────────────────────────────────────────────────────
              _SectionHeader('IMU'),
              const SizedBox(height: 8),
              _DropdownCard(
                title: 'IMU-Datenrate',
                options: BleConstants.imuRates.map((r) => '$r Hz').toList(),
                value: _imuRateIdx.clamp(0, BleConstants.imuRates.length - 1),
                onChanged: (v) => setState(() => _imuRateIdx = v),
                onSend: () => _send(ble, BleConstants.cfgImuRate, _imuRateIdx),
              ),
              const SizedBox(height: 10),
              _DropdownCard(
                title: 'Accel-Bereich',
                options: BleConstants.accelRanges,
                value: _accelIdx.clamp(0, BleConstants.accelRanges.length - 1),
                onChanged: (v) => setState(() => _accelIdx = v),
                onSend: () => _send(ble, BleConstants.cfgAccelRange, _accelIdx),
              ),
              const SizedBox(height: 10),
              _DropdownCard(
                title: 'Gyro-Bereich',
                options: BleConstants.gyroRanges,
                value: _gyroIdx.clamp(0, BleConstants.gyroRanges.length - 1),
                onChanged: (v) => setState(() => _gyroIdx = v),
                onSend: () => _send(ble, BleConstants.cfgGyroRange, _gyroIdx),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _sendAll(ble),
                  icon: const Icon(Icons.send),
                  label: const Text('Alle Einstellungen senden'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF00E5CC),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _GainCard extends StatelessWidget {
  final int gain;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;
  const _GainCard(
      {required this.gain,
      required this.onChanged,
      required this.onChangeEnd});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Audio-Gain',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  '$gain',
                  style: const TextStyle(
                      color: Color(0xFF00E5CC), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: gain.toDouble(),
              min: 0,
              max: 80,
              divisions: 80,
              onChanged: (v) => onChanged(v.round()),
              onChangeEnd: (v) => onChangeEnd(v.round()),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: TextStyle(color: Colors.grey, fontSize: 10)),
                Text('80', style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownCard extends StatelessWidget {
  final String title;
  final List<String> options;
  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback onSend;
  const _DropdownCard({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButton<int>(
                    value: value,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E2E),
                    underline: const SizedBox(),
                    items: [
                      for (int i = 0; i < options.length; i++)
                        DropdownMenuItem(value: i, child: Text(options[i])),
                    ],
                    onChanged: (v) {
                      if (v != null) onChanged(v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onSend,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('Senden'),
            ),
          ],
        ),
      ),
    );
  }
}
