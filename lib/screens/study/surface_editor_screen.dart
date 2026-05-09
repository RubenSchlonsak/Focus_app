import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/subject.dart';
import '../../services/ble_service.dart';
import '../../services/study_manager.dart';
import 'recording_screen.dart';

/// [subject] non-null  → recording flow (shows "Aufnahme starten" button).
/// [subject] null      → standalone edit mode (accessed from StudyTab).
class SurfaceEditorScreen extends StatefulWidget {
  final Subject? subject;
  const SurfaceEditorScreen({super.key, this.subject});

  @override
  State<SurfaceEditorScreen> createState() => _SurfaceEditorScreenState();
}

class _SurfaceEditorScreenState extends State<SurfaceEditorScreen> {
  late List<String> _list;

  bool get _recordingFlow => widget.subject != null;

  @override
  void initState() {
    super.initState();
    _list = List.from(context.read<StudyManager>().surfaces);
  }

  void _startRecording() {
    if (_list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mindestens einen Untergrund auswählen')),
      );
      return;
    }
    if (!context.read<BleService>().isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gerät nicht verbunden')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordingScreen(
          subject: widget.subject!,
          surfaces: List.from(_list),
        ),
      ),
    );
  }

  void _addDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Untergrund hinzufügen'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'z. B. Kunstrasen')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<StudyManager>().addSurface(ctrl.text.trim());
                setState(() => _list.add(ctrl.text.trim()));
              }
              Navigator.pop(context);
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  void _editDialog(int i) {
    final ctrl = TextEditingController(text: _list[i]);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Untergrund bearbeiten'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<StudyManager>().updateSurface(i, ctrl.text.trim());
                setState(() => _list[i] = ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_recordingFlow
            ? 'Untergründe wählen'
            : 'Untergründe bearbeiten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Zurücksetzen',
            onPressed: () {
              context.read<StudyManager>().resetToDefaults();
              setState(
                  () => _list = List.from(context.read<StudyManager>().surfaces));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_recordingFlow)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Reihenfolge per Drag anpassen. Alle Untergründe werden nacheinander aufgenommen.',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _list.length,
              onReorder: (o, n) {
                setState(() {
                  if (n > o) n--;
                  _list.insert(n, _list.removeAt(o));
                });
              },
              itemBuilder: (_, i) => ListTile(
                key: ValueKey('$i${_list[i]}'),
                leading: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle, color: Colors.grey),
                ),
                title: Text(_list[i]),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                      onPressed: () => _editDialog(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          size: 18, color: Colors.redAccent),
                      onPressed: () => setState(() => _list.removeAt(i)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Untergrund hinzufügen'),
                    ),
                  ),
                  if (_recordingFlow) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.fiber_manual_record,
                            color: Colors.red, size: 18),
                        label: Text(
                            'Aufnahme starten (${_list.length} Untergründe)'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
