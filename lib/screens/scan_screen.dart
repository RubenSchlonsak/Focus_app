import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../ble/ble_constants.dart';
import '../services/ble_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _permissionsGranted = false;
  bool _connecting = false;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) {
      setState(() => _permissionsGranted = true);
      return;
    }
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (mounted) {
      setState(() => _permissionsGranted = results.values.every((s) => s.isGranted));
    }
  }

  Future<void> _startScan() async {
    if (!_permissionsGranted) {
      await _requestPermissions();
      return;
    }
    context.read<BleService>().startScan();
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _connecting = true;
      _connectingId = device.remoteId.str;
    });
    await context.read<BleService>().connect(device);
    if (mounted) {
      setState(() {
        _connecting = false;
        _connectingId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FOCUS-Sense'),
        actions: [
          StreamBuilder<BluetoothAdapterState>(
            stream: FlutterBluePlus.adapterState,
            builder: (_, snap) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.bluetooth,
                color: snap.data == BluetoothAdapterState.on
                    ? const Color(0xFF00E5CC)
                    : Colors.red,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<BleService>(
        builder: (_, ble, _) => Column(
          children: [
            _buildHeader(ble),
            if (ble.error != null) _buildError(ble.error!),
            Expanded(
              child: ble.scanResults.isEmpty
                  ? _buildEmpty(ble.isScanning)
                  : _buildList(ble),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BleService ble) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gerät suchen',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: const Color(0xFF00E5CC)),
                ),
                Text(
                  'Service: ${BleConstants.serviceUuid.substring(0, 8)}…',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: ble.isScanning || _connecting ? null : _startScan,
            icon: ble.isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black87),
                  )
                : const Icon(Icons.search, size: 18),
            label: Text(ble.isScanning ? 'Suche…' : 'Scannen'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withAlpha(102)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(color: Colors.red, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool scanning) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 80,
            color: scanning
                ? const Color(0xFF00E5CC)
                : Colors.grey.withAlpha(102),
          ),
          const SizedBox(height: 16),
          Text(
            scanning ? 'Suche nach Geräten…' : 'Kein Gerät gefunden',
            style: const TextStyle(color: Colors.grey),
          ),
          if (!scanning) ...[
            const SizedBox(height: 8),
            Text(
              'Stellen Sie sicher, dass FOCUS-Sense\neingeschaltet und in Reichweite ist.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(BleService ble) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: ble.scanResults.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = ble.scanResults[i];
        final dev = r.device;
        final isTarget =
            dev.platformName == BleConstants.targetDeviceName;
        final isBusy =
            _connecting && _connectingId == dev.remoteId.str;

        return Card(
          color: isTarget
              ? const Color(0xFF00E5CC).withAlpha(20)
              : const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isTarget
                ? const BorderSide(color: Color(0xFF00E5CC))
                : BorderSide.none,
          ),
          child: ListTile(
            leading: Icon(
              Icons.sensors,
              color: isTarget ? const Color(0xFF00E5CC) : Colors.grey,
            ),
            title: Text(
              dev.platformName.isEmpty ? 'Unbekannt' : dev.platformName,
              style: TextStyle(
                color: isTarget ? const Color(0xFF00E5CC) : Colors.white,
                fontWeight:
                    isTarget ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              '${dev.remoteId.str}  •  ${r.rssi} dBm',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            trailing: isBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton(
                    onPressed:
                        _connecting ? null : () => _connect(dev),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTarget
                          ? const Color(0xFF00E5CC)
                          : Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Verbinden'),
                  ),
          ),
        );
      },
    );
  }
}
