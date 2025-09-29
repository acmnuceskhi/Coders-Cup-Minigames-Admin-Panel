import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coders_cup_minigame_admin/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class AddGamePage extends StatefulWidget {
  final String? gameId;
  final Map<String, dynamic>? initialData;

  const AddGamePage({super.key, this.gameId, this.initialData});

  @override
  State<AddGamePage> createState() => _AddGamePageState();
}

class _AddGamePageState extends State<AddGamePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _limitCtrl = TextEditingController(text: '100');
  final _backgroundUrlCtrl = TextEditingController();
  final _bottomLeftUrlCtrl = TextEditingController();
  final _bottomRightUrlCtrl = TextEditingController();
  Color? _primaryColor;
  final _primaryHexCtrl = TextEditingController();
  final List<_FieldEntry> _fields = [
    _FieldEntry(
      labelController: TextEditingController(text: 'Name'),
      type: 'text',
      required: false,
    ),
  ];
  bool _codeBased = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    _backgroundUrlCtrl.dispose();
    _bottomLeftUrlCtrl.dispose();
    _bottomRightUrlCtrl.dispose();
    _primaryHexCtrl.dispose();
    for (final f in _fields) {
      f.labelController.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _nameCtrl.text = (d['name'] as String?) ?? '';
      _limitCtrl.text = (d['limit']?.toString()) ?? '';
      _backgroundUrlCtrl.text = (d['backgroundImage'] as String?) ?? '';
      _bottomLeftUrlCtrl.text = (d['bottomLeftImage'] as String?) ?? '';
      _bottomRightUrlCtrl.text = (d['bottomRightImage'] as String?) ?? '';
      if (d['primaryColor'] is String) {
        final rawHex = (d['primaryColor'] as String);
        _primaryHexCtrl.text = rawHex;
        final hex = rawHex.replaceAll('#', '');
        try {
          final v = int.parse(hex, radix: 16);
          _primaryColor = Color(v);
        } catch (_) {}
      }
      if (d['formFields'] is List) {
        _fields.clear();
        for (final f in (d['formFields'] as List)) {
          _fields.add(
            _FieldEntry(
              labelController: TextEditingController(text: f['label'] ?? ''),
              type: f['type'] ?? 'text',
              required: f['required'] ?? false,
            ),
          );
        }
      }
      _codeBased = d['codeBased'] ?? false;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();
      final limit = int.tryParse(_limitCtrl.text);
      final fields = _fields
          .map(
            (f) => {
              'label': f.labelController.text.trim(),
              'type': f.type,
              'required': f.required,
            },
          )
          .toList();

      final gamesRef = FirebaseFirestore.instance.collection('games');
      final payload = <String, dynamic>{
        'name': name,
        if (limit != null) 'limit': limit,
        'codeBased': _codeBased,
        'formFields': fields,
        if (_primaryColor != null)
          'primaryColor':
              '#${_primaryColor!.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      };

      final bg = _backgroundUrlCtrl.text.trim();
      if (bg.isNotEmpty) payload['backgroundImage'] = bg;
      final bl = _bottomLeftUrlCtrl.text.trim();
      if (bl.isNotEmpty) payload['bottomLeftImage'] = bl;
      final br = _bottomRightUrlCtrl.text.trim();
      if (br.isNotEmpty) payload['bottomRightImage'] = br;

      if (widget.gameId != null) {
        // update: if admin cleared the limit field (limit == null) we should
        // remove the stored 'limit' field from the document so it becomes null.
        if (limit == null) {
          final updatePayload = Map<String, dynamic>.from(payload);
          updatePayload['limit'] = FieldValue.delete();
          await gamesRef.doc(widget.gameId).update(updatePayload);
        } else {
          await gamesRef.doc(widget.gameId).update(payload);
        }
      } else {
        await gamesRef.add(payload);
      }
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Game')),
      body: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 12.0,
          horizontal: isLandscape(context)
              ? MediaQuery.of(context).size.width * 0.2
              : MediaQuery.of(context).size.width * 0.05,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('Name')],
                  ),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _limitCtrl,
                decoration: const InputDecoration(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('Limit')],
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? null
                    : (int.tryParse(v) == null ? 'Invalid' : null),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Form fields',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Name and Email are captured from Google sign-in automatically; you do not need to add them as form fields.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 8),
              ..._fields.asMap().entries.map((entry) {
                final idx = entry.key;
                final field = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: field.labelController,
                          decoration: const InputDecoration(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text('Label')],
                            ),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: field.type,
                          items: const [
                            DropdownMenuItem(
                              value: 'text',
                              child: Text('Text'),
                            ),
                            DropdownMenuItem(
                              value: 'number',
                              child: Text('Number'),
                            ),
                            DropdownMenuItem(
                              value: 'date',
                              child: Text('Date'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => field.type = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Req', style: TextStyle(fontSize: 12)),
                          Checkbox(
                            value: field.required,
                            onChanged: (v) =>
                                setState(() => field.required = v ?? false),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() => _fields.removeAt(idx));
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => _fields.add(
                      _FieldEntry(
                        labelController: TextEditingController(),
                        type: 'text',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add field'),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Code-based game (give users unique codes)'),
                value: _codeBased,
                onChanged: (v) => setState(() => _codeBased = v ?? false),
              ),
              const SizedBox(height: 12),
              // Color picker
              ListTile(
                title: const Text('Primary color (optional)'),
                trailing: Container(
                  width: 36,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _primaryColor ?? Colors.transparent,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                onTap: () async {
                  Color temp = _primaryColor ?? Colors.blue;
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Pick primary color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: temp,
                          onColorChanged: (c) => temp = c,
                          enableAlpha: false,
                          showLabel: false,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _primaryColor = temp);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Select'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _primaryHexCtrl,
                decoration: const InputDecoration(
                  labelText: 'Primary color hex (e.g. #FF3366FF) - optional',
                  hintText: '#AARRGGBB or #RRGGBB',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final t = v.trim().replaceAll('#', '');
                  if (t.length != 6 && t.length != 8) return 'Invalid hex';
                  try {
                    int.parse(t, radix: 16);
                    return null;
                  } catch (_) {
                    return 'Invalid hex';
                  }
                },
                onChanged: (v) {
                  final t = v.trim().replaceAll('#', '');
                  if (t.length == 6 || t.length == 8) {
                    try {
                      final vInt = int.parse(t, radix: 16);
                      setState(() => _primaryColor = Color(vInt));
                    } catch (_) {}
                  }
                },
              ),
              const SizedBox(height: 12),
              // Image URL fields
              TextFormField(
                controller: _backgroundUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Background image URL (optional)',
                  hintText: 'https://...',
                ),
                validator: (v) =>
                    (v != null && v.isNotEmpty && !v.startsWith('http'))
                    ? 'Invalid URL'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bottomLeftUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bottom-left image URL (optional)',
                  hintText: 'https://...',
                ),
                validator: (v) =>
                    (v != null && v.isNotEmpty && !v.startsWith('http'))
                    ? 'Invalid URL'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bottomRightUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bottom-right image URL (optional)',
                  hintText: 'https://...',
                ),
                validator: (v) =>
                    (v != null && v.isNotEmpty && !v.startsWith('http'))
                    ? 'Invalid URL'
                    : null,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldEntry {
  TextEditingController labelController;
  String type;
  bool required;

  _FieldEntry({
    required this.labelController,
    required this.type,
    this.required = false,
  });
}
