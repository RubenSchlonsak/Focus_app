import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/subject.dart';
import '../../services/ble_service.dart';
import '../../services/recording_service.dart';
import '../../services/study_manager.dart';
import '../viewer/session_viewer_screen.dart';

class RecordingScreen extends StatefulWidget {
  final Subject subject;
  final List<String> surfaces;
  const RecordingScreen(
      {super.key, required this.subject, required this.surfaces});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  bool _hasStarted = false;

  void _start() {
    context.read<RecordingService>().startRecording(
          subject: widget.subject,
          surfaces: widget.surfaces,
          ble: context.read<BleService>(),
        );
    setState(() => _hasStarted = true);
  }

  void _pause() => context.read<RecordingService>().pauseRecording();

  void _resume() =>
      context.read<RecordingService>().resumeRecording(context.read<BleService>());

  Future<void> _end() async {
    final rec       = context.read<RecordingService>();
    final navigator = Navigator.of(context);
    final mgr       = context.read<StudyManager>();

    if (!rec.isPaused) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Aufnahme beenden?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IMU-Samples:   ${rec.imuSampleCount}'),
              Text('Audio-Samples: ${rec.audioSampleCount}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Weiter aufnehmen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Beenden', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final result = await _showSaveDialog(mgr);
    if (result == null || !mounted) return;

    final session = await rec.stopAndSave(name: result.$1, folder: result.$2);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => SessionViewerScreen(session: session)),
      (route) => route.isFirst,
    );
  }

  Future<(String, String)?> _showSaveDialog(StudyManager mgr) {
    final defaultName =
        '${widget.subject.age}J_${widget.subject.gender}_${_timestamp()}';
    return showDialog<(String, String)>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SaveDialog(defaultName: defaultName, studyManager: mgr),
    );
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingService>(
      builder: (_, rec, _) {
        if (!_hasStarted) return _buildReady();

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Aufnahme abbrechen?'),
                content: const Text('Alle Daten gehen verloren.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Weiter'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                    child: const Text('Abbrechen',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            if (ok == true && mounted) {
              rec.pauseRecording(); // stop streams
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0A0A14),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0A0A14),
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  if (rec.isPaused)
                    const Icon(Icons.pause_circle_filled,
                        color: Colors.orangeAccent, size: 14)
                  else
                    _BlinkingDot(isRecording: rec.isRecording),
                  const SizedBox(width: 8),
                  Text(
                    rec.isPaused ? 'PAUSE' : 'REC',
                    style: TextStyle(
                      color: rec.isPaused ? Colors.orangeAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _fmtDuration(rec.elapsed),
                    style: const TextStyle(fontSize: 22, color: Colors.white),
                  ),
                ],
              ),
              actions: [
                if (rec.isPaused)
                  TextButton.icon(
                    onPressed: _resume,
                    icon: const Icon(Icons.play_arrow, color: Color(0xFF00E5CC)),
                    label: const Text('WEITER',
                        style: TextStyle(color: Color(0xFF00E5CC))),
                  )
                else
                  TextButton.icon(
                    onPressed: _pause,
                    icon: const Icon(Icons.pause, color: Colors.orangeAccent),
                    label: const Text('PAUSE',
                        style: TextStyle(color: Colors.orangeAccent)),
                  ),
                TextButton.icon(
                  onPressed: _end,
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: Colors.redAccent),
                  label: const Text('ENDE',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(flex: 4, child: _SurfaceNav(rec: rec)),
                  Expanded(flex: 2, child: _ImuMini(az: rec.recentAz)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: _AudioBar(level: rec.audioLevel),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Stat('IMU', '${rec.imuSampleCount}'),
                        _Stat('Audio', '${rec.audioSampleCount}'),
                        _Stat('Marker', '${rec.markers.length}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReady() {
    final s = widget.subject;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        title: const Text('Aufnahme vorbereiten'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PROBAND',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Row(children: [
                        _InfoChip('${s.age} J'),
                        const SizedBox(width: 8),
                        _InfoChip(s.genderLabel),
                        const SizedBox(width: 8),
                        _InfoChip('${s.weightKg} kg'),
                        const SizedBox(width: 8),
                        _InfoChip('EU ${s.shoeSize}'),
                      ]),
                      if (s.notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(s.notes,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Untergründe (${widget.surfaces.length})',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 11, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Card(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < widget.surfaces.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${i + 1}. ${widget.surfaces[i]}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.fiber_manual_record,
                      color: Colors.white, size: 18),
                  label: const Text('AUFNAHME STARTEN',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

// ── Save dialog ────────────────────────────────────────────────────────────
class _SaveDialog extends StatefulWidget {
  final String defaultName;
  final StudyManager studyManager;
  const _SaveDialog({required this.defaultName, required this.studyManager});

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _folderCtrl;
  List<String> _folders = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl   = TextEditingController(text: widget.defaultName);
    _folderCtrl = TextEditingController(text: 'Studie_1');
    widget.studyManager.listFolders().then((folders) {
      if (!mounted) return;
      setState(() {
        _folders = folders;
        if (folders.isNotEmpty) _folderCtrl.text = folders.first;
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _folderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aufnahme speichern'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Proband_01',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _folderCtrl,
              decoration: const InputDecoration(
                labelText: 'Ordner',
                hintText: 'Ordnername eingeben',
              ),
            ),
            if (_folders.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Vorhandene Ordner:',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final f in _folders)
                    ActionChip(
                      label: Text(f, style: const TextStyle(fontSize: 12)),
                      onPressed: () => setState(() => _folderCtrl.text = f),
                      backgroundColor: _folderCtrl.text == f
                          ? const Color(0xFF00E5CC).withAlpha(40)
                          : null,
                      side: BorderSide(
                        color: _folderCtrl.text == f
                            ? const Color(0xFF00E5CC)
                            : Colors.white24,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final name   = _nameCtrl.text.trim();
            final folder = _folderCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, (name, folder));
          },
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Speichern'),
        ),
      ],
    );
  }
}

// ── Info chip (ready screen) ───────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5CC).withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF00E5CC).withAlpha(60)),
        ),
        child: Text(label,
            style: const TextStyle(color: Color(0xFF00E5CC), fontSize: 13)),
      );
}

// ── Surface navigator ──────────────────────────────────────────────────────
class _SurfaceNav extends StatelessWidget {
  final RecordingService rec;
  const _SurfaceNav({required this.rec});

  @override
  Widget build(BuildContext context) {
    final surfaces = rec.surfaces;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00E5CC), width: 2),
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF00E5CC).withAlpha(15),
          ),
          child: Column(children: [
            Text(
              rec.currentSurface.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF00E5CC),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2),
            ),
            const SizedBox(height: 4),
            Text('${rec.surfaceIdx + 1} / ${rec.surfaceCount}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Text('Untergrund wählen',
              style: TextStyle(
                  color: Colors.grey, fontSize: 11, letterSpacing: 0.8)),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < surfaces.length; i++)
                  _SurfaceChip(
                    label: '${i + 1}. ${surfaces[i]}',
                    selected: i == rec.surfaceIdx,
                    onTap: () => rec.jumpToSurface(i),
                  ),
              ],
            ),
          ),
        ),
        if (rec.surfaceIdx == rec.surfaceCount - 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 4),
            child: Text(
              '✓ Letzter Untergrund — ENDE drücken wenn fertig',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _SurfaceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SurfaceChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00E5CC).withAlpha(30)
              : Colors.white.withAlpha(10),
          border: Border.all(
            color: selected ? const Color(0xFF00E5CC) : Colors.white24,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF00E5CC) : Colors.white54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── IMU mini-chart ─────────────────────────────────────────────────────────
class _ImuMini extends StatelessWidget {
  final List<double> az;
  const _ImuMini({required this.az});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('IMU  (az)',
              style: TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 4),
          Expanded(
            child: az.isEmpty
                ? const Center(
                    child: Text('Warte auf IMU-Daten…',
                        style:
                            TextStyle(color: Colors.white24, fontSize: 12)))
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: az.length.toDouble(),
                      minY: -4,
                      maxY: 4,
                      clipData: const FlClipData.all(),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (int i = 0; i < az.length; i++)
                              FlSpot(i.toDouble(), az[i])
                          ],
                          isCurved: false,
                          color: const Color(0xFF00E5CC),
                          barWidth: 1.2,
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
                          border: Border.all(color: Colors.white10)),
                      gridData: const FlGridData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                    ),
                    duration: Duration.zero,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Audio level bar ────────────────────────────────────────────────────────
class _AudioBar extends StatelessWidget {
  final double level;
  const _AudioBar({required this.level});

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(0.0, 1.0);
    return Row(children: [
      const Text('AUD',
          style: TextStyle(
              color: Colors.grey, fontSize: 10, letterSpacing: 1)),
      const SizedBox(width: 8),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 8,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              clamped > 0.8
                  ? Colors.redAccent
                  : clamped > 0.5
                      ? Colors.orangeAccent
                      : const Color(0xFF00E5CC),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ]);
}

// ── Blinking dot ───────────────────────────────────────────────────────────
class _BlinkingDot extends StatefulWidget {
  final bool isRecording;
  const _BlinkingDot({required this.isRecording});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _ctrl,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
              color: Colors.redAccent, shape: BoxShape.circle),
        ),
      );
}
