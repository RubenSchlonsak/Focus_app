import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ble_service.dart';
import 'audio_tab.dart';
import 'config_tab.dart';
import 'imu_tab.dart';
import 'status_tab.dart';
import 'study/study_tab.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  int _tab = 0;

  static const _bodies = [
    StatusTab(),
    ImuTab(),
    AudioTab(),
    ConfigTab(),
    StudyTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (_, ble, _) => Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.sensors, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ble.device?.platformName ?? 'FOCUS-Sense',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _MtuBadge(mtu: ble.mtu),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: 'Trennen',
              onPressed: () => ble.disconnect(),
            ),
          ],
        ),
        body: IndexedStack(index: _tab, children: _bodies),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Status',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_outlined),
              activeIcon: Icon(Icons.show_chart),
              label: 'IMU',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.graphic_eq_outlined),
              activeIcon: Icon(Icons.graphic_eq),
              label: 'Audio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Konfig',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.science_outlined),
              activeIcon: Icon(Icons.science),
              label: 'Studie',
            ),
          ],
        ),
      ),
    );
  }
}

class _MtuBadge extends StatelessWidget {
  final int mtu;
  const _MtuBadge({required this.mtu});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5CC).withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF00E5CC), width: 0.5),
      ),
      child: Text(
        'MTU $mtu',
        style: const TextStyle(color: Color(0xFF00E5CC), fontSize: 11),
      ),
    );
  }
}
