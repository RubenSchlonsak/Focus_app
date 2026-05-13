import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../ble/adpcm.dart';
import '../ble/ble_constants.dart';
import '../models/session_marker.dart';
import '../models/study_session.dart';
import '../models/subject.dart';
import 'ble_service.dart';

class RecordingService extends ChangeNotifier {
  // ── Recording state ───────────────────────────────────────────────────────
  bool _isRecording = false;
  bool _isPaused = false;
  Subject? _subject;
  List<String> _surfaces = [];
  int _surfaceIdx = 0;

  DateTime? _startTime;
  DateTime? _pauseStart;
  Duration _totalPausedDuration = Duration.zero;
  int _imuRateHz = 104;
  int _audioSampleRate = 16000;
  int _deviceMtu = 247;

  // ── Data buffers ──────────────────────────────────────────────────────────
  // [timestamp_ms, ax, ay, az, gx, gy, gz]
  final List<List<double>> _imuSamples = [];
  // Audio stored as Uint8List chunks — avoids the ~8× memory blow-up of List<int>
  final List<Uint8List> _audioChunks = [];
  int _audioPcmByteCount = 0;
  final List<SessionMarker> _markers = [];

  // ── Live-preview for RecordingScreen ─────────────────────────────────────
  final List<double> _recentAz = [];
  double _audioLevel = 0;

  // Device-side timestamp anchoring (uint32 micros, wraps at ~71 min)
  int? _firstDeviceUs; // raw uint32 from first packet

  // ── Subscriptions / timer ─────────────────────────────────────────────────
  StreamSubscription<List<int>>? _imuSub;
  StreamSubscription<List<int>>? _audioSub;
  Timer? _ticker;

  DateTime _lastNotify = DateTime(0);
  static const _notifyInterval = Duration(milliseconds: 100);

  // ── Getters ───────────────────────────────────────────────────────────────
  bool     get isRecording       => _isRecording;
  bool     get isPaused          => _isPaused;
  int      get surfaceIdx        => _surfaceIdx;
  int      get surfaceCount      => _surfaces.length;
  String   get currentSurface    => _surfaces.isNotEmpty ? _surfaces[_surfaceIdx] : '';
  String?  get prevSurfaceName   => _surfaceIdx > 0 ? _surfaces[_surfaceIdx - 1] : null;
  String?  get nextSurfaceName   => _surfaceIdx < _surfaces.length - 1 ? _surfaces[_surfaceIdx + 1] : null;
  List<String> get surfaces      => List.unmodifiable(_surfaces);
  int      get imuSampleCount    => _imuSamples.length;
  int      get audioSampleCount  => _audioPcmBytes.length ~/ 2;
  List<double> get recentAz      => List.unmodifiable(_recentAz);
  double   get audioLevel        => _audioLevel;
  List<SessionMarker> get markers => List.unmodifiable(_markers);

  Duration get elapsed {
    if (_startTime == null) return Duration.zero;
    final wall = (_isPaused && _pauseStart != null)
        ? _pauseStart!.difference(_startTime!)
        : DateTime.now().difference(_startTime!);
    final net = wall - _totalPausedDuration;
    return net.isNegative ? Duration.zero : net;
  }

  // ── Start ─────────────────────────────────────────────────────────────────
  void startRecording({
    required Subject subject,
    required List<String> surfaces,
    required BleService ble,
  }) {
    _subject = subject;
    _surfaces = List.from(surfaces);
    _surfaceIdx = 0;
    _startTime = DateTime.now();
    _imuRateHz = ble.status != null
        ? BleConstants.imuRates[ble.status!.imuRateIdx.clamp(0, BleConstants.imuRates.length - 1)]
        : 104;
    _audioSampleRate = ble.status != null
        ? (ble.status!.audioRateIdx == 1 ? 16000 : 8000)
        : 16000;
    _deviceMtu = ble.mtu;

    _imuSamples.clear();
    _audioPcmBytes.clear();
    _markers.clear();
    _recentAz.clear();
    _firstDeviceUs = null;
    _isPaused = false;
    _pauseStart = null;
    _totalPausedDuration = Duration.zero;

    // First marker: surface 0 at t=0
    _markers.add(SessionMarker(
      timestampMs: 0,
      surfaceIndex: 0,
      surfaceName: _surfaces[0],
    ));

    _imuSub  = ble.imuStream.listen(_onImuData);
    _audioSub = ble.audioStream.listen(_onAudioData);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());

    _isRecording = true;
    notifyListeners();
  }

  // ── Data handlers ─────────────────────────────────────────────────────────
  // ImuPacket: 28 bytes per sample (matches firmware struct)
  //   [0..3]   uint32 t_us  — device micros() timestamp
  //   [4..27]  6× float32   ax, ay, az, gx, gy, gz
  static const int _imuSampleBytes = 28;

  void _onImuData(List<int> raw) {
    if (!_isRecording || raw.length < _imuSampleBytes || raw.length % _imuSampleBytes != 0) return;
    final bd = ByteData.sublistView(Uint8List.fromList(raw));
    final n  = raw.length ~/ _imuSampleBytes;

    for (int i = 0; i < n; i++) {
      final o   = i * _imuSampleBytes;
      // Device micros() as unsigned 32-bit — read as int32 then mask to handle Dart's signed int
      final tUs = bd.getUint32(o, Endian.little);

      // Anchor on first sample; handle uint32 wrap-around (~71 min) via unsigned subtraction
      _firstDeviceUs ??= tUs;
      final elapsedUs = (tUs - _firstDeviceUs!) & 0xFFFFFFFF;
      final sampleMs  = elapsedUs / 1000.0;

      _imuSamples.add([
        sampleMs,
        bd.getFloat32(o + 4,  Endian.little), // ax
        bd.getFloat32(o + 8,  Endian.little), // ay
        bd.getFloat32(o + 12, Endian.little), // az
        bd.getFloat32(o + 16, Endian.little), // gx
        bd.getFloat32(o + 20, Endian.little), // gy
        bd.getFloat32(o + 24, Endian.little), // gz
      ]);
      _recentAz.add(bd.getFloat32(o + 12, Endian.little));
    }
    if (_recentAz.length > 150) _recentAz.removeRange(0, _recentAz.length - 150);
    _throttledNotify();
  }

  // Audio packet layout: [t_us:4B][predictor:2B][step:1B][pad:1B][ADPCM nibbles...]
  void _onAudioData(List<int> raw) {
    if (!_isRecording || raw.length < 9) return;
    final decoded = decodeAdpcmPacket(raw);
    if (decoded.isEmpty) return;
    final pcm = ByteData(decoded.length * 2);
    double peak = 0;
    for (int i = 0; i < decoded.length; i++) {
      final s = decoded[i];
      pcm.setInt16(i * 2, s, Endian.little);
      final abs = s.abs();
      if (abs > peak) peak = abs.toDouble();
    }
    _audioPcmBytes.addAll(pcm.buffer.asUint8List());
    _audioLevel = peak / 32768.0;
    _throttledNotify();
  }

  void _throttledNotify() {
    final now = DateTime.now();
    if (now.difference(_lastNotify) >= _notifyInterval) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  // ── Surface navigation ────────────────────────────────────────────────────
  void nextSurface() {
    if (!_isRecording || _surfaceIdx >= _surfaces.length - 1) return;
    _surfaceIdx++;
    _addMarker(isCorrection: false);
    notifyListeners();
  }

  void prevSurface() {
    if (!_isRecording || _surfaceIdx <= 0) return;
    _surfaceIdx--;
    _addMarker(isCorrection: true);
    notifyListeners();
  }

  void jumpToSurface(int index) {
    if (!_isRecording || index < 0 || index >= _surfaces.length || index == _surfaceIdx) return;
    final isCorrection = index < _surfaceIdx;
    _surfaceIdx = index;
    _addMarker(isCorrection: isCorrection);
    notifyListeners();
  }

  void _addMarker({required bool isCorrection}) {
    final ms = elapsed.inMilliseconds;
    _markers.add(SessionMarker(
      timestampMs: ms,
      surfaceIndex: _surfaceIdx,
      surfaceName: _surfaces[_surfaceIdx],
      isCorrection: isCorrection,
    ));
  }

  // ── Pause / Resume ────────────────────────────────────────────────────────
  void pauseRecording() {
    if (!_isRecording || _isPaused) return;
    _isPaused = true;
    _pauseStart = DateTime.now();
    _ticker?.cancel();
    _ticker = null;
    _imuSub?.cancel();  _imuSub = null;
    _audioSub?.cancel(); _audioSub = null;
    notifyListeners();
  }

  void resumeRecording(BleService ble) {
    if (!_isRecording || !_isPaused) return;
    _totalPausedDuration += DateTime.now().difference(_pauseStart!);
    _isPaused = false;
    _pauseStart = null;
    _imuSub  = ble.imuStream.listen(_onImuData);
    _audioSub = ble.audioStream.listen(_onAudioData);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    notifyListeners();
  }

  // ── Stop & Save ───────────────────────────────────────────────────────────
  Future<StudySession> stopAndSave({
    required String name,
    required String folder,
  }) async {
    final durationMs = elapsed.inMilliseconds; // capture before teardown
    _ticker?.cancel();
    await _imuSub?.cancel();
    await _audioSub?.cancel();
    _isRecording = false;
    _isPaused = false;
    notifyListeners();

    final sessionId = _buildSessionId(_startTime!);
    final dir = await _createSessionDir(folder: folder, name: name);

    await Future.wait([
      _writeMetadataJson(dir, sessionId, durationMs),
      _writeImuCsv(dir),
      _writeAudioWav(dir),
      _writeMarkersJson(dir),
      _writeSessionLog(dir, sessionId, durationMs),
    ]);

    return StudySession(
      sessionId: sessionId,
      directoryPath: dir,
      startTime: _startTime!,
      durationMs: durationMs,
      subject: _subject!,
      surfaces: _surfaces,
      markers: List.from(_markers),
      imuSampleCount: _imuSamples.length,
      audioSampleCount: _audioPcmBytes.length ~/ 2,
      imuRateHz: _imuRateHz,
      audioSampleRate: _audioSampleRate,
    );
  }

  // ── File writers ──────────────────────────────────────────────────────────

  Future<String> _createSessionDir({
    required String folder,
    required String name,
  }) async {
    final base = await getApplicationDocumentsDirectory();
    final safeFolder = _sanitizeName(folder.isEmpty ? 'Allgemein' : folder);
    final safeName   = _sanitizeName(name.isEmpty ? _buildSessionId(_startTime!) : name);
    String path = '${base.path}/FOCUS-Sense/$safeFolder/$safeName';
    int n = 2;
    while (Directory(path).existsSync()) {
      path = '${base.path}/FOCUS-Sense/$safeFolder/${safeName}_$n';
      n++;
    }
    await Directory(path).create(recursive: true);
    return path;
  }

  static String _sanitizeName(String s) =>
      s.replaceAll(RegExp(r'[<>:"/\\|?*\n\r\t]'), '_').trim();

  Future<void> _writeMetadataJson(String dir, String id, int durationMs) async {
    final session = StudySession(
      sessionId: id,
      directoryPath: dir,
      startTime: _startTime!,
      durationMs: durationMs,
      subject: _subject!,
      surfaces: _surfaces,
      markers: List.from(_markers),
      imuSampleCount: _imuSamples.length,
      audioSampleCount: _audioPcmBytes.length ~/ 2,
      imuRateHz: _imuRateHz,
      audioSampleRate: _audioSampleRate,
    );
    await File('$dir/metadata.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(session.toJson()));
  }

  Future<void> _writeImuCsv(String dir) async {
    final sb = StringBuffer('timestamp_ms,ax_g,ay_g,az_g,gx_dps,gy_dps,gz_dps\n');
    for (final row in _imuSamples) {
      sb.write('${row[0].toInt()},'
          '${row[1].toStringAsFixed(5)},'
          '${row[2].toStringAsFixed(5)},'
          '${row[3].toStringAsFixed(5)},'
          '${row[4].toStringAsFixed(3)},'
          '${row[5].toStringAsFixed(3)},'
          '${row[6].toStringAsFixed(3)}\n');
    }
    await File('$dir/imu_data.csv').writeAsString(sb.toString());
  }

  Future<void> _writeAudioWav(String dir) async {
    final wavBytes = _buildWav(_audioPcmBytes, _audioSampleRate);
    await File('$dir/audio.wav').writeAsBytes(wavBytes);
  }

  Future<void> _writeMarkersJson(String dir) async {
    final json = _markers.map((m) => m.toJson()).toList();
    await File('$dir/markers.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  Future<void> _writeSessionLog(String dir, String id, int durationMs) async {
    final s = _subject!;
    final dur = Duration(milliseconds: durationMs);
    final m = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = dur.inSeconds.remainder(60).toString().padLeft(2, '0');

    final sb = StringBuffer();
    sb.writeln('FOCUS-Sense Studie');
    sb.writeln('=' * 40);
    sb.writeln('Session:  $id');
    sb.writeln('Datum:    ${_formatDateTime(_startTime!)}');
    sb.writeln();
    sb.writeln('PROBAND');
    sb.writeln('-' * 20);
    sb.writeln('Alter:        ${s.age} Jahre');
    sb.writeln('Gewicht:      ${s.weightKg.toStringAsFixed(1)} kg');
    sb.writeln('Größe:        ${s.heightCm} cm');
    sb.writeln('Schuhgröße:   ${s.shoeSize}');
    sb.writeln('Geschlecht:   ${s.genderLabel}');
    if (s.notes.isNotEmpty) sb.writeln('Notizen:      ${s.notes}');
    sb.writeln();
    sb.writeln('GERÄT');
    sb.writeln('-' * 20);
    sb.writeln('IMU-Rate:     $_imuRateHz Hz');
    sb.writeln('Audio-Rate:   $_audioSampleRate Hz');
    sb.writeln('MTU:          $_deviceMtu B');
    sb.writeln();
    sb.writeln('AUFNAHME');
    sb.writeln('-' * 20);
    sb.writeln('Dauer:        $m:$sec');
    sb.writeln('IMU-Samples:  ${_imuSamples.length}');
    sb.writeln('Audio-Smpl.:  ${_audioPcmBytes.length ~/ 2}');
    sb.writeln();
    sb.writeln('UNTERGRÜNDE & ZEITMARKER');
    sb.writeln('-' * 20);
    for (final mk in _markers) {
      final corr = mk.isCorrection ? ' [Korrektur]' : '';
      sb.writeln('[${mk.timeLabel}] ${mk.surfaceIndex + 1}. ${mk.surfaceName}$corr');
    }

    await File('$dir/session_log.txt').writeAsString(sb.toString());
  }

  // ── WAV helper ────────────────────────────────────────────────────────────
  static Uint8List _buildWav(List<int> pcmBytes, int sampleRate) {
    const numChannels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = pcmBytes.length;
    final chunkSize = 36 + dataSize;

    final h = ByteData(44);
    // RIFF
    h.setUint8(0, 0x52); h.setUint8(1, 0x49); h.setUint8(2, 0x46); h.setUint8(3, 0x46);
    h.setUint32(4, chunkSize, Endian.little);
    // WAVE
    h.setUint8(8, 0x57); h.setUint8(9, 0x41); h.setUint8(10, 0x56); h.setUint8(11, 0x45);
    // fmt
    h.setUint8(12, 0x66); h.setUint8(13, 0x6D); h.setUint8(14, 0x74); h.setUint8(15, 0x20);
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);  // PCM
    h.setUint16(22, numChannels, Endian.little);
    h.setUint32(24, sampleRate, Endian.little);
    h.setUint32(28, byteRate, Endian.little);
    h.setUint16(32, blockAlign, Endian.little);
    h.setUint16(34, bitsPerSample, Endian.little);
    // data
    h.setUint8(36, 0x64); h.setUint8(37, 0x61); h.setUint8(38, 0x74); h.setUint8(39, 0x61);
    h.setUint32(40, dataSize, Endian.little);

    return Uint8List.fromList([...h.buffer.asUint8List(), ...pcmBytes]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _buildSessionId(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}'
      '-${t.month.toString().padLeft(2, '0')}'
      '-${t.day.toString().padLeft(2, '0')}'
      '_${t.hour.toString().padLeft(2, '0')}'
      '${t.minute.toString().padLeft(2, '0')}'
      '${t.second.toString().padLeft(2, '0')}';

  static String _formatDateTime(DateTime t) {
    return '${t.day.toString().padLeft(2, '0')}.'
        '${t.month.toString().padLeft(2, '0')}.'
        '${t.year}  '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }
}
