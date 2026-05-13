import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_session.dart';
import '../models/surface_label_list.dart';

class StudyManager extends ChangeNotifier {
  static const _prefKey      = 'focus_surfaces';
  static const _listsKey     = 'focus_surface_lists';

  static const _defaultSurfaces = [
    'Asphalt', 'Beton', 'Kopfsteinpflaster', 'Gras',
    'Waldboden', 'Kies', 'Fliesen', 'Teppich', 'Holzparkett', 'Sand',
  ];

  static const _defaultLabelLists = [
    {
      'name': 'Standard',
      'surfaces': [
        'Schotter', 'Sand', 'Asphalt', 'Gehweg',
        'Kopfsteinpflaster', 'Dirt Road', 'Gras',
      ],
    }
  ];

  List<String> _surfaces = List.from(_defaultSurfaces);
  List<SurfaceLabelList> _labelLists = [];

  List<String> get surfaces => List.unmodifiable(_surfaces);
  List<SurfaceLabelList> get labelLists => List.unmodifiable(_labelLists);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getStringList(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      _surfaces = saved;
    }

    final listsJson = prefs.getString(_listsKey);
    if (listsJson != null) {
      try {
        final decoded = jsonDecode(listsJson) as List;
        _labelLists = decoded
            .map((e) => SurfaceLabelList.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    if (_labelLists.isEmpty) {
      _labelLists = _defaultLabelLists
          .map((m) => SurfaceLabelList.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    notifyListeners();
  }

  // ── Label list CRUD ───────────────────────────────────────────────────────

  void addLabelList(String name, List<String> surfaces) {
    _labelLists.add(SurfaceLabelList(name: name.trim(), surfaces: List.from(surfaces)));
    _saveLists();
    notifyListeners();
  }

  void updateLabelList(int index, String name, List<String> surfaces) {
    _labelLists[index] =
        SurfaceLabelList(name: name.trim(), surfaces: List.from(surfaces));
    _saveLists();
    notifyListeners();
  }

  void deleteLabelList(int index) {
    _labelLists.removeAt(index);
    _saveLists();
    notifyListeners();
  }

  Future<void> _saveLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _listsKey,
      jsonEncode(_labelLists.map((l) => l.toJson()).toList()),
    );
  }

  void addSurface(String name) {
    if (name.trim().isEmpty) return;
    _surfaces.add(name.trim());
    _save();
    notifyListeners();
  }

  void removeSurface(int index) {
    _surfaces.removeAt(index);
    _save();
    notifyListeners();
  }

  void updateSurface(int index, String name) {
    if (name.trim().isEmpty) return;
    _surfaces[index] = name.trim();
    _save();
    notifyListeners();
  }

  void reorderSurfaces(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _surfaces.removeAt(oldIndex);
    _surfaces.insert(newIndex, item);
    _save();
    notifyListeners();
  }

  void resetToDefaults() {
    _surfaces = List.from(_defaultSurfaces);
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, _surfaces);
  }

  // ── Session file system ───────────────────────────────────────────────────

  Future<String> get rootDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/FOCUS-Sense');
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<List<String>> listFolders() async {
    final root = Directory(await rootDir);
    if (!root.existsSync()) return [];
    final folders = root
        .listSync()
        .whereType<Directory>()
        .map((d) => d.path.split(Platform.pathSeparator).last)
        .where((name) => !name.startsWith('.'))
        .toList()
      ..sort();
    return folders;
  }

  Future<List<StudySession>> loadAllSessions() async {
    final root = Directory(await rootDir);
    if (!root.existsSync()) return [];

    final sessions = <StudySession>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (entity.path.split(Platform.pathSeparator).last != 'metadata.json') continue;
      try {
        final json = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        sessions.add(StudySession.fromJson(json, entity.parent.path));
      } catch (_) {}
    }
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  Future<void> deleteSession(StudySession session) async {
    final dir = Directory(session.directoryPath);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
