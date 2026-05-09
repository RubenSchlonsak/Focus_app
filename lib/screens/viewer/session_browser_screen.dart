import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/study_session.dart';
import '../../services/study_manager.dart';
import '../../utils/session_zip.dart';
import 'session_viewer_screen.dart';

class SessionBrowserScreen extends StatefulWidget {
  const SessionBrowserScreen({super.key});

  @override
  State<SessionBrowserScreen> createState() =>
      _SessionBrowserScreenState();
}

class _SessionBrowserScreenState extends State<SessionBrowserScreen> {
  late Future<List<StudySession>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      _future = context.read<StudyManager>().loadAllSessions();

  Future<void> _share(StudySession session) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ZIP wird erstellt…'),
        duration: Duration(seconds: 60),
      ),
    );
    try {
      final zipPath = await buildSessionZip(session);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await SharePlus.instance.share(ShareParams(
        files: [XFile(zipPath)],
        text: 'FOCUS-Sense Session ${session.sessionId}',
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export fehlgeschlagen')),
      );
    }
  }

  Future<void> _delete(StudySession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Session löschen?'),
        content: Text(
            '${session.sessionId} wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<StudyManager>().deleteSession(session);
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aufnahmen')),
      body: FutureBuilder<List<StudySession>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final sessions = snap.data ?? [];
          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open,
                      size: 64, color: Colors.white24),
                  SizedBox(height: 12),
                  Text('Noch keine Aufnahmen vorhanden',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _SessionCard(
              session: sessions[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        SessionViewerScreen(session: sessions[i])),
              ),
              onShare: () => _share(sessions[i]),
              onDelete: () => _delete(sessions[i]),
            ),
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final StudySession session;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
  });

  static const _months = [
    'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'
  ];

  @override
  Widget build(BuildContext context) {
    final s = session.subject;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Date badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF00E5CC).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF00E5CC).withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  '${session.startTime.day.toString().padLeft(2, '0')}\n'
                  '${_months[session.startTime.month - 1]}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF00E5CC), fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  if (session.folderName.isNotEmpty)
                    Text(session.folderName,
                        style: const TextStyle(
                            color: Color(0xFF00E5CC),
                            fontSize: 10,
                            letterSpacing: 0.5)),
                  const SizedBox(height: 3),
                  Text(
                    '${s.age} J  •  ${s.genderLabel}  •  '
                    '${s.weightKg} kg  •  ${s.heightCm} cm  •  EU ${s.shoeSize}',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.timer_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(session.durationLabel,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11)),
                    const SizedBox(width: 12),
                    const Icon(Icons.layers_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${session.surfaces.length} Untergründe',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11)),
                  ]),
                ],
              ),
            ),
            // Actions
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.share_outlined,
                    color: Color(0xFF00E5CC), size: 20),
                onPressed: onShare,
                tooltip: 'Exportieren',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                onPressed: onDelete,
                tooltip: 'Löschen',
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
