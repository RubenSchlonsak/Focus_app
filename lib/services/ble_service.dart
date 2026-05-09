import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/adpcm.dart';
import '../ble/ble_constants.dart';
import '../models/info_data.dart';
import '../models/imu_data.dart';
import '../models/status_data.dart';

class BleService extends ChangeNotifier {
  // ── Raw-data broadcast streams (used by RecordingService) ─────────────────
  final _imuCtrl   = StreamController<List<int>>.broadcast();
  final _audioCtrl = StreamController<List<int>>.broadcast();

  Stream<List<int>> get imuStream   => _imuCtrl.stream;
  Stream<List<int>> get audioStream => _audioCtrl.stream;

  // ── Scan ──────────────────────────────────────────────────────────────────
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];

  // ── Connection ────────────────────────────────────────────────────────────
  BluetoothDevice? _device;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  int _mtu = 23;

  // ── Cached write characteristics ──────────────────────────────────────────
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _cfgChar;
  BluetoothCharacteristic? _statusChar;
  BluetoothCharacteristic? _infoChar;

  // ── Data ──────────────────────────────────────────────────────────────────
  StatusData? _status;
  InfoData?   _infoData;
  final ImuChartData _imuChartData = ImuChartData();
  List<double> _audioSamples = [];

  // ── UI throttle (avoid flooding chart at 208 Hz / 131 pkt/s) ─────────────
  DateTime _lastImuUi    = DateTime(0);
  DateTime _lastAudioUi  = DateTime(0);
  static const _uiInterval = Duration(milliseconds: 33); // ~30 fps

  // ── Error ─────────────────────────────────────────────────────────────────
  String? _error;

  // ── Subscriptions ─────────────────────────────────────────────────────────
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<int>? _mtuSub;
  StreamSubscription<List<int>>? _imuSub;
  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<List<int>>? _statusSub;

  // ── Getters ───────────────────────────────────────────────────────────────
  bool               get isScanning    => _isScanning;
  List<ScanResult>   get scanResults   => List.unmodifiable(_scanResults);
  BluetoothDevice?   get device        => _device;
  bool               get isConnected   =>
      _connectionState == BluetoothConnectionState.connected;
  int                get mtu           => _mtu;
  StatusData?        get status        => _status;
  InfoData?          get infoData      => _infoData;
  ImuChartData       get imuChartData  => _imuChartData;
  List<double>       get audioSamples  => List.unmodifiable(_audioSamples);
  String?            get error         => _error;

  // ── Scan ──────────────────────────────────────────────────────────────────
  Future<void> startScan() async {
    if (_isScanning) return;
    _scanResults.clear();
    _error = null;
    _isScanning = true;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: 15),
      );
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        notifyListeners();
      });
      await Future.delayed(const Duration(seconds: 15));
    } catch (e) {
      _error = e.toString();
    } finally {
      await stopScan();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    _isScanning = false;
    notifyListeners();
  }

  // ── Connect ───────────────────────────────────────────────────────────────
  Future<void> connect(BluetoothDevice device) async {
    _error = null;
    try {
      await device.connect(autoConnect: false);
      _device = device;

      _connSub = device.connectionState.listen((state) {
        _connectionState = state;
        if (state == BluetoothConnectionState.disconnected) {
          _teardown();
        }
        notifyListeners();
      });

      // The firmware calls requestMtuExchange(247) in its connectCallback.
      // We only listen — a second exchange from the app triggers a silent
      // GATT reset on MIUI that wipes all CCCD subscriptions.
      _mtuSub = device.mtu.listen((mtu) {
        _mtu = mtu;
        notifyListeners();
      });

      await _negotiateMtu(device);

      final services = await device.discoverServices();
      await _setupCharacteristics(services);
      await readStatus();
      await readInfo();

      // Re-enable streams if the firmware's persisted config left them off.
      if (_status == null || !_status!.imuActive || !_status!.audioActive) {
        await sendCmd(0x03); // bit0 = IMU, bit1 = Audio
      }
    } catch (e) {
      _error = e.toString();
      _device = null;
      notifyListeners();
    }
  }

  Future<void> _negotiateMtu(BluetoothDevice device) async {
    if (!Platform.isAndroid) return;

    // Give the peripheral-side MTU request a short chance to complete first.
    // If it stays at the default 23, Android as the GATT client must request it.
    try {
      await device.mtu
          .firstWhere((mtu) => mtu >= BleConstants.targetMtu)
          .timeout(const Duration(milliseconds: 600));
      return;
    } on TimeoutException {
      // Fall through and request MTU from the central.
    } catch (_) {
      // Fall through and request MTU from the central.
    }

    try {
      final mtu = await device.requestMtu(BleConstants.targetMtu);
      _mtu = mtu;
      notifyListeners();
    } catch (e) {
      _error = 'MTU request failed: $e';
      notifyListeners();
    }
  }

  Future<void> _setupCharacteristics(List<BluetoothService> services) async {
    final svc = services.firstWhere(
      (s) => s.serviceUuid.toString().toLowerCase() ==
          BleConstants.serviceUuid.toLowerCase(),
      orElse: () => throw Exception('FOCUS-Sense service not found'),
    );

    // Collect characteristics first, then subscribe sequentially.
    // Android BLE stack requires each CCCD write to complete (onDescriptorWrite)
    // before the next one starts — parallel writes leave subscribed=0.
    BluetoothCharacteristic? imuChar, audioChar, statusChar;
    for (final c in svc.characteristics) {
      final uuid = c.characteristicUuid.toString().toLowerCase();
      if (uuid == BleConstants.imuCharUuid.toLowerCase()) {
        imuChar = c;
      } else if (uuid == BleConstants.audioCharUuid.toLowerCase()) {
        audioChar = c;
      } else if (uuid == BleConstants.cmdCharUuid.toLowerCase()) {
        _cmdChar = c;
      } else if (uuid == BleConstants.cfgCharUuid.toLowerCase()) {
        _cfgChar = c;
      } else if (uuid == BleConstants.statusCharUuid.toLowerCase()) {
        statusChar = c;
      } else if (uuid == BleConstants.infoCharUuid.toLowerCase()) {
        _infoChar = c;
      }
    }

    if (imuChar != null) {
      _imuSub = imuChar.onValueReceived.listen(_onImuData);
      await imuChar.setNotifyValue(true);
    }
    if (audioChar != null) {
      _audioSub = audioChar.onValueReceived.listen(_onAudioData);
      await audioChar.setNotifyValue(true);
    }
    if (statusChar != null) {
      _statusChar = statusChar;
      _statusSub = statusChar.onValueReceived.listen(_onStatusData);
      await statusChar.setNotifyValue(true);
    }

    notifyListeners();
  }

  // ── Data handlers ─────────────────────────────────────────────────────────
  // ImuPacket layout (28 bytes, packed, little-endian):
  //   [0..3]   uint32  t_us   — device micros() timestamp
  //   [4..7]   float32 ax
  //   [8..11]  float32 ay
  //   [12..15] float32 az
  //   [16..19] float32 gx
  //   [20..23] float32 gy
  //   [24..27] float32 gz
  static const int _imuSampleBytes = 28;

  void _onImuData(List<int> value) {
    if (value.length < _imuSampleBytes || value.length % _imuSampleBytes != 0) return;
    _imuCtrl.add(value); // forward raw bytes to RecordingService
    final bd = ByteData.sublistView(Uint8List.fromList(value));
    final n = value.length ~/ _imuSampleBytes;
    for (int i = 0; i < n; i++) {
      final o = i * _imuSampleBytes;
      _imuChartData.add(
        ax: bd.getFloat32(o + 4,  Endian.little),
        ay: bd.getFloat32(o + 8,  Endian.little),
        az: bd.getFloat32(o + 12, Endian.little),
        gx: bd.getFloat32(o + 16, Endian.little),
        gy: bd.getFloat32(o + 20, Endian.little),
        gz: bd.getFloat32(o + 24, Endian.little),
      );
    }
    final now = DateTime.now();
    if (now.difference(_lastImuUi) >= _uiInterval) {
      _lastImuUi = now;
      notifyListeners();
    }
  }

  // Audio packet layout: [t_us:4B][predictor:2B][step:1B][pad:1B][ADPCM nibbles...]
  void _onAudioData(List<int> value) {
    if (value.length < 9) return; // 8B header + at least 1 nibble byte
    _audioCtrl.add(value); // forward raw packet; RecordingService decodes independently
    final decoded = decodeAdpcmPacket(value);
    _audioSamples = [..._audioSamples, ...decoded.map((s) => s.toDouble())];
    if (_audioSamples.length > 512) {
      _audioSamples = _audioSamples.sublist(_audioSamples.length - 512);
    }
    final now = DateTime.now();
    if (now.difference(_lastAudioUi) >= _uiInterval) {
      _lastAudioUi = now;
      notifyListeners();
    }
  }

  void _onStatusData(List<int> value) {
    if (value.length < 7) return;
    _status = StatusData(
      flags:        value[0],
      audioGain:    value[1],
      audioRateIdx: value[2],
      imuRateIdx:   value[3],
      accelIdx:     value[4],
      gyroIdx:      value[5],
      audioDrops:   value[6],
    );
    notifyListeners();
    readInfo(); // refresh actual hardware values whenever status changes
  }

  void _onInfoData(List<int> value) {
    if (value.length < 11) return;
    final bd = ByteData.sublistView(Uint8List.fromList(value));
    _infoData = InfoData(
      flags:        value[0],
      audioGain:    value[1],
      audioRateHz:  bd.getUint32(2, Endian.little),
      imuRateHz:    bd.getUint16(6, Endian.little),
      accelRangeG:  value[8],
      gyroRangeDps: bd.getUint16(9, Endian.little),
    );
    notifyListeners();
  }

  // ── Read STATUS + INFO ────────────────────────────────────────────────────
  Future<void> readStatus() async {
    if (_statusChar == null) return;
    try {
      final value = await _statusChar!.read();
      _onStatusData(value);
    } catch (_) {}
  }

  Future<void> readInfo() async {
    if (_infoChar == null) return;
    try {
      final value = await _infoChar!.read();
      _onInfoData(value);
    } catch (_) {}
  }

  // ── Commands ──────────────────────────────────────────────────────────────
  Future<void> sendCmd(int flags) async {
    if (_cmdChar == null) return;
    try {
      await _cmdChar!.write([0x01, flags], withoutResponse: false);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendCfg(int id, int val) async {
    if (_cfgChar == null) return;
    try {
      await _cfgChar!.write([id, val], withoutResponse: false);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void clearImuData() {
    _imuChartData.clear();
    notifyListeners();
  }

  void clearAudioData() {
    _audioSamples = [];
    notifyListeners();
  }

  // ── Disconnect ────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    await _device?.disconnect();
  }

  void _teardown() {
    _mtuSub?.cancel();    _mtuSub = null;
    _imuSub?.cancel();    _imuSub = null;
    _audioSub?.cancel();  _audioSub = null;
    _statusSub?.cancel(); _statusSub = null;
    _connSub?.cancel();   _connSub = null;
    _cmdChar = null;
    _cfgChar = null;
    _statusChar = null;
    _infoChar = null;
    _status = null;
    _infoData = null;
    _imuChartData.clear();
    _audioSamples = [];
    _connectionState = BluetoothConnectionState.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _teardown();
    _imuCtrl.close();
    _audioCtrl.close();
    super.dispose();
  }
}
