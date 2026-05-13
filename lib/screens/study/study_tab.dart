import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/study_manager.dart';
import '../viewer/session_browser_screen.dart';
import 'label_lists_screen.dart';
import 'subject_form_screen.dart';
import 'surface_editor_screen.dart';

class StudyTab extends StatelessWidget {
  const StudyTab({super.key});

  static const _surfaceColors = [
    Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF5722),
    Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF00BCD4),
    Color(0xFFF44336), Color(0xFF8BC34A), Color(0xFF607D8B), Color(0xFFFFEB3B),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<StudyManager>(
      builder: (_, mgr, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActionCard(
              icon: Icons.fiber_manual_record,
              iconColor: Colors.redAccent,
              title: 'Neue Aufnahme',
              subtitle: 'Probanden­daten → Untergründe → Aufnahme starten',
              buttonLabel: 'Starten',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubjectFormScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.folder_open,
              iconColor: const Color(0xFF00E5CC),
              title: 'Aufnahmen anzeigen',
              subtitle: 'Gespeicherte Sessions ansehen, exportieren oder löschen',
              buttonLabel: 'Öffnen',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SessionBrowserScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.list_alt,
              iconColor: Colors.orangeAccent,
              title: 'Untergrund-Listen',
              subtitle: 'Benannte Listen anlegen und beim Aufnahme-Setup laden',
              buttonLabel: 'Verwalten',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LabelListsScreen()),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Untergrundliste',
                  style: TextStyle(
                      color: Color(0xFF00E5CC),
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SurfaceEditorScreen()),
                  ),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Bearbeiten'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5CC),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (int i = 0; i < mgr.surfaces.length; i++)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              _surfaceColors[i % _surfaceColors.length],
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white)),
                        ),
                        title: Text(mgr.surfaces[i]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10)),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
