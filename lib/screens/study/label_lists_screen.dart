import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/surface_label_list.dart';
import '../../services/study_manager.dart';

class LabelListsScreen extends StatelessWidget {
  const LabelListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Untergrund-Listen')),
      body: Consumer<StudyManager>(
        builder: (_, mgr, _) {
          final lists = mgr.labelLists;
          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.list_alt, size: 56, color: Colors.white24),
                  const SizedBox(height: 12),
                  const Text('Noch keine Listen',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showEditDialog(context, mgr),
                    icon: const Icon(Icons.add),
                    label: const Text('Neue Liste'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lists.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ListCard(
              list: lists[i],
              onEdit: () => _showEditDialog(context, mgr, index: i),
              onDelete: () => _confirmDelete(context, mgr, i),
            ),
          );
        },
      ),
      floatingActionButton: Consumer<StudyManager>(
        builder: (_, mgr, _) => FloatingActionButton(
          onPressed: () => _showEditDialog(context, mgr),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    StudyManager mgr, {
    int? index,
  }) async {
    final existing = index != null ? mgr.labelLists[index] : null;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _LabelListEditorScreen(
          initial: existing,
          onSave: (name, surfaces) {
            if (index != null) {
              mgr.updateLabelList(index, name, surfaces);
            } else {
              mgr.addLabelList(name, surfaces);
            }
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, StudyManager mgr, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Liste löschen?'),
        content: Text(
            '"${mgr.labelLists[index].name}" wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) mgr.deleteLabelList(index);
  }
}

class _ListCard extends StatelessWidget {
  final SurfaceLabelList list;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ListCard(
      {required this.list, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(list.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    list.surfaces.join(' · '),
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('${list.surfaces.length} Untergründe',
                      style: const TextStyle(
                          color: Color(0xFF00E5CC), fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 20, color: Color(0xFF00E5CC)),
              onPressed: onEdit,
              tooltip: 'Bearbeiten',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.redAccent),
              onPressed: onDelete,
              tooltip: 'Löschen',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editor ────────────────────────────────────────────────────────────────────

class _LabelListEditorScreen extends StatefulWidget {
  final SurfaceLabelList? initial;
  final void Function(String name, List<String> surfaces) onSave;
  const _LabelListEditorScreen({this.initial, required this.onSave});

  @override
  State<_LabelListEditorScreen> createState() => _LabelListEditorScreenState();
}

class _LabelListEditorScreenState extends State<_LabelListEditorScreen> {
  late final TextEditingController _nameCtrl;
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.initial?.name ?? '');
    _items = List.from(widget.initial?.surfaces ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Untergrund hinzufügen'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                const InputDecoration(hintText: 'z. B. Waldweg')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _items.add(ctrl.text.trim()));
              }
              Navigator.pop(context);
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  void _edit(int i) {
    final ctrl = TextEditingController(text: _items[i]);
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
                setState(() => _items[i] = ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Listennamen eingeben')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mindestens einen Untergrund hinzufügen')),
      );
      return;
    }
    widget.onSave(_nameCtrl.text.trim(), _items);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.initial == null ? 'Neue Liste' : 'Liste bearbeiten'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Speichern',
                style: TextStyle(color: Color(0xFF00E5CC))),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Listenname',
                hintText: 'z. B. Outdoor-Studie',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Noch keine Untergründe',
                        style: TextStyle(color: Colors.grey)))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _items.length,
                    onReorder: (o, n) {
                      setState(() {
                        if (n > o) n--;
                        _items.insert(n, _items.removeAt(o));
                      });
                    },
                    itemBuilder: (_, i) => ListTile(
                      key: ValueKey('$i${_items[i]}'),
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle,
                            color: Colors.grey),
                      ),
                      title: Text(_items[i]),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit,
                                size: 18, color: Colors.grey),
                            onPressed: () => _edit(i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 18, color: Colors.redAccent),
                            onPressed: () =>
                                setState(() => _items.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Untergrund hinzufügen'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
