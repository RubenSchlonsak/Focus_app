import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ble_service.dart';

class StatusTab extends StatelessWidget {
  const StatusTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (_, ble, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConnectionCard(ble: ble),
            const SizedBox(height: 14),
            _StreamCard(ble: ble),
            const SizedBox(height: 14),
            _HwConfigCard(ble: ble),
          ],
        ),
      ),
    );
  }
}

// ── Connection info ────────────────────────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  final BleService ble;
  const _ConnectionCard({required this.ble});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Verbindung'),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5CC),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Verbunden',
                    style: TextStyle(color: Color(0xFF00E5CC))),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.memory, size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              Text('MTU: ${ble.mtu} B',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.bluetooth, size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ble.device?.remoteId.str ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: ble.readStatus,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Status aktualisieren'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stream toggles ─────────────────────────────────────────────────────────

class _StreamCard extends StatelessWidget {
  final BleService ble;
  const _StreamCard({required this.ble});

  @override
  Widget build(BuildContext context) {
    final imu    = ble.status?.imuActive   ?? false;
    final audio  = ble.status?.audioActive ?? false;
    final imuOk  = ble.status?.imuOk       ?? true;
    final drops  = ble.status?.audioDrops  ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Streams'),
            const SizedBox(height: 12),
            _StreamRow(
              icon: Icons.show_chart,
              label: 'IMU-Stream',
              active: imu,
              warning: !imuOk ? 'Hardware-Fehler' : null,
              onToggle: (val) =>
                  ble.sendCmd((val ? 0x01 : 0x00) | (audio ? 0x02 : 0x00)),
            ),
            const Divider(height: 24, color: Colors.white12),
            _StreamRow(
              icon: Icons.graphic_eq,
              label: 'Audio-Stream',
              active: audio,
              warning: drops > 0 ? '$drops Drops' : null,
              onToggle: (val) =>
                  ble.sendCmd((imu ? 0x01 : 0x00) | (val ? 0x02 : 0x00)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final String? warning;
  final ValueChanged<bool> onToggle;
  const _StreamRow(
      {required this.icon,
      required this.label,
      required this.active,
      this.warning,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            color: warning != null
                ? Colors.orange
                : active
                    ? const Color(0xFF00E5CC)
                    : Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              Text(
                warning ?? (active ? 'Aktiv' : 'Inaktiv'),
                style: TextStyle(
                  color: warning != null
                      ? Colors.orange
                      : active
                          ? const Color(0xFF00E5CC)
                          : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(value: active, onChanged: onToggle),
      ],
    );
  }
}

// ── Device config read-out (from INFO characteristic — actual HW values) ──────

class _HwConfigCard extends StatelessWidget {
  final BleService ble;
  const _HwConfigCard({required this.ble});

  @override
  Widget build(BuildContext context) {
    final info = ble.infoData;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Gerätekonfiguration'),
            const SizedBox(height: 12),
            if (info == null)
              Row(
                children: [
                  const Text('Noch nicht gelesen',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: ble.readInfo,
                    icon: const Icon(Icons.refresh, size: 15),
                    label: const Text('Laden'),
                  ),
                ],
              )
            else ...[
              _Row('Audio-Gain',  '${info.audioGain}'),
              _Row('Audio-Rate',  info.audioRateStr),
              _Row('IMU-Rate',    info.imuRateStr),
              _Row('Accel-Range', info.accelRangeStr),
              _Row('Gyro-Range',  info.gyroRangeStr),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 0.8));
  }
}
