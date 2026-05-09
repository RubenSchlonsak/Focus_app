import 'package:flutter/material.dart';

import '../../models/subject.dart';
import 'surface_editor_screen.dart';

class SubjectFormScreen extends StatefulWidget {
  const SubjectFormScreen({super.key});

  @override
  State<SubjectFormScreen> createState() => _SubjectFormScreenState();
}

class _SubjectFormScreenState extends State<SubjectFormScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _ageCtrl     = TextEditingController();
  final _weightCtrl  = TextEditingController();
  final _heightCtrl  = TextEditingController();
  final _shoeCtrl    = TextEditingController();
  final _notesCtrl   = TextEditingController();
  String _gender = 'm';

  @override
  void dispose() {
    _ageCtrl.dispose(); _weightCtrl.dispose(); _heightCtrl.dispose();
    _shoeCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    final subject = Subject(
      age:      int.parse(_ageCtrl.text.trim()),
      weightKg: double.parse(_weightCtrl.text.trim().replaceAll(',', '.')),
      heightCm: int.parse(_heightCtrl.text.trim()),
      shoeSize: double.parse(_shoeCtrl.text.trim().replaceAll(',', '.')),
      gender:   _gender,
      notes:    _notesCtrl.text.trim(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurfaceEditorScreen(subject: subject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proband')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Demografische Daten'),
              const SizedBox(height: 12),
              _field(ctrl: _ageCtrl,    label: 'Alter (Jahre)',     hint: '28',
                  type: TextInputType.number,
                  validator: (v) => _intVal(v, 1, 120)),
              const SizedBox(height: 12),
              _field(ctrl: _weightCtrl, label: 'Gewicht (kg)',      hint: '75.0',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _dblVal(v, 10, 300)),
              const SizedBox(height: 12),
              _field(ctrl: _heightCtrl, label: 'Größe (cm)',        hint: '180',
                  type: TextInputType.number,
                  validator: (v) => _intVal(v, 50, 250)),
              const SizedBox(height: 12),
              _field(ctrl: _shoeCtrl,   label: 'Schuhgröße (EU)',   hint: '43',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _dblVal(v, 15, 60)),
              const SizedBox(height: 18),
              _sectionHeader('Geschlecht'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                selected: {_gender},
                onSelectionChanged: (s) => setState(() => _gender = s.first),
                segments: const [
                  ButtonSegment(value: 'm', label: Text('männlich')),
                  ButtonSegment(value: 'f', label: Text('weiblich')),
                  ButtonSegment(value: 'd', label: Text('divers')),
                ],
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? const Color(0xFF00E5CC).withAlpha(50)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _sectionHeader('Notizen (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'z. B. Verletzungen, Besonderheiten…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Weiter → Untergründe'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(text,
      style: const TextStyle(
          color: Color(0xFF00E5CC), fontSize: 13, fontWeight: FontWeight.w700));

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required TextInputType type,
    required String? Function(String?) validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: type,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      );

  String? _intVal(String? v, int min, int max) {
    if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Ungültige Zahl';
    if (n < min || n > max) return '$min – $max';
    return null;
  }

  String? _dblVal(String? v, double min, double max) {
    if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
    final n = double.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null) return 'Ungültige Zahl';
    if (n < min || n > max) return '$min – $max';
    return null;
  }
}
