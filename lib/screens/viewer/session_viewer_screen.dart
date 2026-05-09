import 'dart:io';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/session_zip.dart';

import '../../models/session_marker.dart';
import '../../models/study_session.dart';

class SessionViewerScreen extends StatefulWidget {
  final StudySession session;
  const SessionViewerScreen({super.key, required this.session});

  @override
  State<SessionViewerScreen> createState() =>
      _SessionViewerScreenState();
}

class _SessionViewerScreenState extends State<SessionViewerScreen> {
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    return _Data(
      imu: await _loadImu(),
      audio: await _loadAudio(),
    );
  }

  Future<List<List<double>>> _loadImu() async {
    final f = File('${widget.session.directoryPath}/imu_data.csv');
    if (!f.existsSync()) return [];
    final lines = await f.readAsLines();
    const max = 2000;
    final data = lines.skip(1).toList();
    final step = ((data.length / max).ceil()).clamp(1, 1 << 20);
    final out = <List<double>>[];
    for (int i = 0; i < data.length; i += step) {
      final p = data[i].split(',');
      if (p.length < 7) continue;
      out.add(p.map((e) => double.tryParse(e) ?? 0.0).toList());
    }
    return out;
  }

  Future<List<double>> _loadAudio() async {
    final f = File('${widget.session.directoryPath}/audio.wav');
    if (!f.existsSync()) return [];
    final bytes = await f.readAsBytes();
    if (bytes.length < 44) return [];
    final pcm = bytes.sublist(44);
    final bd = ByteData.sublistView(Uint8List.fromList(pcm));
    const max = 4000;
    final numSamples = pcm.length ~/ 2;
    final step = ((numSamples / max).ceil()).clamp(1, 1 << 20);
    final out = <double>[];
    for (int i = 0; i < numSamples; i += step) {
      out.add(bd.getInt16(i * 2, Endian.little).toDouble());
    }
    return out;
  }

  Future<void> _share() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ZIP wird erstellt…'),
        duration: Duration(seconds: 60),
      ),
    );
    try {
      final zipPath = await buildSessionZip(widget.session);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await SharePlus.instance.share(ShareParams(
        files: [XFile(zipPath)],
        text: 'FOCUS-Sense ${widget.session.sessionId}',
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export fehlgeschlagen')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.session.sessionId, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Exportieren',
              onPressed: _share),
        ],
      ),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Daten laden…',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          final d = snap.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SubjectCard(session: widget.session),
              const SizedBox(height: 12),
              _TimelineCard(
                markers: widget.session.markers,
                totalMs: widget.session.durationMs,
              ),
              if (d != null && d.imu.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ImuCard(rows: d.imu),
              ],
              if (d != null && d.audio.isNotEmpty) ...[
                const SizedBox(height: 12),
                _AudioCard(samples: d.audio),
              ],
              const SizedBox(height: 12),
              _FilesCard(dirPath: widget.session.directoryPath),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _Data {
  final List<List<double>> imu;
  final List<double> audio;
  const _Data({required this.imu, required this.audio});
}

// ── Subject card ───────────────────────────────────────────────────────────
class _SubjectCard extends StatelessWidget {
  final StudySession session;
  const _SubjectCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session.subject;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('PROBAND'),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 6, children: [
            _kv('Alter', '${s.age} J'),
            _kv('Geschlecht', s.genderLabel),
            _kv('Gewicht', '${s.weightKg} kg'),
            _kv('Größe', '${s.heightCm} cm'),
            _kv('Schuhgr.', 'EU ${s.shoeSize}'),
            _kv('IMU', '${session.imuRateHz} Hz'),
            _kv('Audio', '${session.audioSampleRate} Hz'),
            _kv('Dauer', session.durationLabel),
            _kv('IMU-Smpl.', '${session.imuSampleCount}'),
            _kv('Audio-Smpl.', '${session.audioSampleCount}'),
          ]),
          if (s.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Notizen: ${s.notes}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$k: ',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(v, style: const TextStyle(fontSize: 12)),
      ]);

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: Colors.grey, fontSize: 11, letterSpacing: 0.8));
}

// ── Timeline card ──────────────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  final List<SessionMarker> markers;
  final int totalMs;

  static const _colors = [
    Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF5722),
    Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF00BCD4),
    Color(0xFFF44336), Color(0xFF8BC34A), Color(0xFF607D8B), Color(0xFFFFEB3B),
  ];

  const _TimelineCard(
      {required this.markers, required this.totalMs});

  Color _col(SessionMarker m) =>
      m.isCorrection ? Colors.grey : _colors[m.surfaceIndex % _colors.length];

  int _flex(int i) {
    final start = markers[i].timestampMs;
    final end = i + 1 < markers.length
        ? markers[i + 1].timestampMs
        : totalMs;
    return ((end - start) * 1000 / totalMs.clamp(1, totalMs))
        .round()
        .clamp(1, 1 << 20);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ZEITMARKER',
              style: TextStyle(
                  color: Colors.grey, fontSize: 11, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          // Colored timeline bar
          SizedBox(
            height: 34,
            child: Row(
              children: [
                for (int i = 0; i < markers.length; i++)
                  Flexible(
                    flex: _flex(i),
                    child: Tooltip(
                      message:
                          '${markers[i].surfaceName}\n${markers[i].timeLabel}',
                      child: Container(
                        height: 34,
                        color: _col(markers[i]),
                        alignment: Alignment.center,
                        child: Text(
                          markers[i].surfaceName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Marker list
          for (final mk in markers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: _col(mk), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('[${mk.timeLabel}]',
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontFamily: 'monospace')),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${mk.surfaceIndex + 1}. ${mk.surfaceName}'
                    '${mk.isCorrection ? '  [Korrektur]' : ''}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

// ── IMU viewer card ────────────────────────────────────────────────────────
class _ImuCard extends StatefulWidget {
  final List<List<double>> rows;
  const _ImuCard({required this.rows});

  @override
  State<_ImuCard> createState() => _ImuCardState();
}

class _ImuCardState extends State<_ImuCard> {
  bool _accel = true;

  List<FlSpot> _spots(int col) => [
        for (final r in widget.rows) FlSpot(r[0], r[col]),
      ];

  LineChartBarData _bar(List<FlSpot> s, Color c) => LineChartBarData(
        spots: s,
        isCurved: false,
        color: c,
        barWidth: 1,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final minX = rows.isEmpty ? 0.0 : rows.first[0];
    final maxX = rows.isEmpty ? 1.0 : rows.last[0];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('IMU',
                style: TextStyle(
                    color: Colors.grey, fontSize: 11, letterSpacing: 0.8)),
            const Spacer(),
            ToggleButtons(
              isSelected: [_accel, !_accel],
              onPressed: (i) => setState(() => _accel = i == 0),
              constraints:
                  const BoxConstraints(minHeight: 28, minWidth: 72),
              borderRadius: BorderRadius.circular(6),
              children: const [Text('Accel'), Text('Gyro')],
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: _accel ? -4 : -600,
                maxY: _accel ? 4 : 600,
                clipData: const FlClipData.all(),
                lineBarsData: _accel
                    ? [
                        _bar(_spots(1), Colors.redAccent),
                        _bar(_spots(2), Colors.greenAccent),
                        _bar(_spots(3), Colors.blueAccent),
                      ]
                    : [
                        _bar(_spots(4), Colors.orangeAccent),
                        _bar(_spots(5), Colors.yellowAccent),
                        _bar(_spots(6), Colors.purpleAccent),
                      ],
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.white12)),
                gridData: const FlGridData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
              ),
              duration: Duration.zero,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _accel
                ? [
                    _leg('X', Colors.redAccent),
                    _leg('Y', Colors.greenAccent),
                    _leg('Z', Colors.blueAccent),
                  ]
                : [
                    _leg('X', Colors.orangeAccent),
                    _leg('Y', Colors.yellowAccent),
                    _leg('Z', Colors.purpleAccent),
                  ],
          ),
        ]),
      ),
    );
  }

  Widget _leg(String l, Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 2.5, color: c),
          const SizedBox(width: 4),
          Text(l, style: TextStyle(color: c, fontSize: 11)),
        ]),
      );
}

// ── Audio viewer card ──────────────────────────────────────────────────────
class _AudioCard extends StatelessWidget {
  final List<double> samples;
  const _AudioCard({required this.samples});

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (int i = 0; i < samples.length; i++)
        FlSpot(i.toDouble(), samples[i]),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AUDIO  (PCM Int16)',
              style: TextStyle(
                  color: Colors.grey, fontSize: 11, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: spots.isEmpty ? 1 : spots.last.x,
                minY: -32768,
                maxY: 32768,
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFF00E5CC),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.white12)),
                gridData: const FlGridData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
              ),
              duration: Duration.zero,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Files card ─────────────────────────────────────────────────────────────
class _FilesCard extends StatelessWidget {
  final String dirPath;
  const _FilesCard({required this.dirPath});

  @override
  Widget build(BuildContext context) {
    final dir = Directory(dirPath);
    final files =
        dir.existsSync() ? dir.listSync().whereType<File>().toList() : <File>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DATEIEN',
              style: TextStyle(
                  color: Colors.grey, fontSize: 11, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          for (final f in files)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined,
                  color: Colors.grey, size: 18),
              title: Text(f.path.split(Platform.pathSeparator).last,
                  style: const TextStyle(fontSize: 13)),
              trailing: Text(_fmtSize(f.lengthSync()),
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 11)),
            ),
        ]),
      ),
    );
  }

  static String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
