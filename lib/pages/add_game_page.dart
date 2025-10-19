import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coders_cup_minigame_admin/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
// no extra foundation import required

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
  // image state: url and storage path (to allow deletion), and optionally a picked file
  PlatformFile? _backgroundPickedFile;
  String? _backgroundUrl;
  String? _backgroundPath;

  PlatformFile? _bottomLeftPickedFile;
  String? _bottomLeftUrl;
  String? _bottomLeftPath;

  PlatformFile? _bottomRightPickedFile;
  String? _bottomRightUrl;
  String? _bottomRightPath;

  bool _bgUploading = false;
  bool _blUploading = false;
  bool _brUploading = false;
  final _descriptionCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
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
  bool _active = true;
  bool _scoreboardDisabled = false;
  // Whether to allow non-NU IDs to register for this game
  bool _allowNonNuIds = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    // no controllers for images to dispose
    _primaryHexCtrl.dispose();
    _descriptionCtrl.dispose();
    _instructionsCtrl.dispose();
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
      _descriptionCtrl.text = (d['description'] as String?) ?? '';
      _instructionsCtrl.text = (d['instructions'] as String?) ?? '';
      _backgroundUrl = (d['backgroundImage'] as String?) ?? null;
      _backgroundPath = (d['backgroundImagePath'] as String?) ?? null;
      _bottomLeftUrl = (d['bottomLeftImage'] as String?) ?? null;
      _bottomLeftPath = (d['bottomLeftImagePath'] as String?) ?? null;
      _bottomRightUrl = (d['bottomRightImage'] as String?) ?? null;
      _bottomRightPath = (d['bottomRightImagePath'] as String?) ?? null;
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
      _active = d['active'] ?? true;
      _scoreboardDisabled = d['scoreboardDisabled'] ?? false;
      // read allowNonNuIds if present in the document
      _allowNonNuIds = d['allowNonNuIds'] ?? false;
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
        'active': _active,
        'scoreboardDisabled': _scoreboardDisabled,
        'allowNonNuIds': _allowNonNuIds,
        'description': _descriptionCtrl.text.trim(),
        'instructions': _instructionsCtrl.text.trim(),
        'formFields': fields,
        if (_primaryColor != null)
          'primaryColor':
              '#${_primaryColor!.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      };

      // attach any already-uploaded image URLs/paths
      if (_backgroundUrl != null && _backgroundUrl!.isNotEmpty) {
        payload['backgroundImage'] = _backgroundUrl;
        if (_backgroundPath != null)
          payload['backgroundImagePath'] = _backgroundPath;
      }
      if (_bottomLeftUrl != null && _bottomLeftUrl!.isNotEmpty) {
        payload['bottomLeftImage'] = _bottomLeftUrl;
        if (_bottomLeftPath != null)
          payload['bottomLeftImagePath'] = _bottomLeftPath;
      }
      if (_bottomRightUrl != null && _bottomRightUrl!.isNotEmpty) {
        payload['bottomRightImage'] = _bottomRightUrl;
        if (_bottomRightPath != null)
          payload['bottomRightImagePath'] = _bottomRightPath;
      }

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
        // If there are picked files for an existing game, upload them now
        final docId = widget.gameId!;
        if (_backgroundPickedFile != null) {
          final m = await _uploadPickedFile(
            docId,
            _backgroundPickedFile!,
            'backgroundImage',
          );
          await gamesRef.doc(docId).update({
            'backgroundImage': m['url'],
            'backgroundImagePath': m['path'],
          });
        }
        if (_bottomLeftPickedFile != null) {
          final m = await _uploadPickedFile(
            docId,
            _bottomLeftPickedFile!,
            'bottomLeftImage',
          );
          await gamesRef.doc(docId).update({
            'bottomLeftImage': m['url'],
            'bottomLeftImagePath': m['path'],
          });
        }
        if (_bottomRightPickedFile != null) {
          final m = await _uploadPickedFile(
            docId,
            _bottomRightPickedFile!,
            'bottomRightImage',
          );
          await gamesRef.doc(docId).update({
            'bottomRightImage': m['url'],
            'bottomRightImagePath': m['path'],
          });
        }
      } else {
        // create doc first, then upload any picked files and update the doc with URLs/paths
        final docRef = await gamesRef.add(payload);
        final docId = docRef.id;
        if (_backgroundPickedFile != null) {
          final m = await _uploadPickedFile(
            docId,
            _backgroundPickedFile!,
            'backgroundImage',
          );
          await gamesRef.doc(docId).update({
            'backgroundImage': m['url'],
            'backgroundImagePath': m['path'],
          });
        }
        if (_bottomLeftPickedFile != null) {
          final m = await _uploadPickedFile(
            docId,
            _bottomLeftPickedFile!,
            'bottomLeftImage',
          );
          await gamesRef.doc(docId).update({
            'bottomLeftImage': m['url'],
            'bottomLeftImagePath': m['path'],
          });
        }
        if (_bottomRightPickedFile != null) {
          final m = await _uploadPickedFile(
            docId,
            _bottomRightPickedFile!,
            'bottomRightImage',
          );
          await gamesRef.doc(docId).update({
            'bottomRightImage': m['url'],
            'bottomRightImagePath': m['path'],
          });
        }
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

  Future<Map<String, String>> _uploadPickedFile(
    String docId,
    PlatformFile file,
    String fieldName,
  ) async {
    // returns {'url': downloadUrl, 'path': fullPath}
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('games')
        .child(docId)
        .child(fieldName)
        .child('${DateTime.now().millisecondsSinceEpoch}_${file.name}');
    final bytes = file.bytes;
    if (bytes == null) throw Exception('Picked file has no bytes');
    await storageRef.putData(bytes);
    final url = await storageRef.getDownloadURL();
    return {'url': url, 'path': storageRef.fullPath};
  }

  Widget _buildImagePickerRow({
    required String label,
    required String? imageUrl,
    required PlatformFile? pickedFile,
    required bool uploading,
    required VoidCallback onPick,
  }) {
    Widget preview;
    if (uploading) {
      preview = const SizedBox(
        width: 64,
        height: 64,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (pickedFile != null) {
      preview = Image.memory(
        pickedFile.bytes!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      preview = Image.network(
        imageUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
      );
    } else {
      preview = Container(
        width: 64,
        height: 64,
        color: Colors.grey[200],
        child: const Icon(Icons.image),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 6),
              Text(
                imageUrl ??
                    (pickedFile != null
                        ? pickedFile.name
                        : 'No image selected'),
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        preview,
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.upload_file),
          label: const Text('Pick'),
        ),
      ],
    );
  }

  Future<void> _pickImage(String field) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.image,
    );
    if (result == null) return;
    final file = result.files.single;
    setState(() {
      if (field == 'background') _backgroundPickedFile = file;
      if (field == 'bottomLeft') _bottomLeftPickedFile = file;
      if (field == 'bottomRight') _bottomRightPickedFile = file;
    });
    // If editing existing game, upload immediately
    if (widget.gameId != null) {
      try {
        setState(() {
          if (field == 'background') _bgUploading = true;
          if (field == 'bottomLeft') _blUploading = true;
          if (field == 'bottomRight') _brUploading = true;
        });
        final m = await _uploadPickedFile(
          widget.gameId!,
          file,
          field == 'background'
              ? 'backgroundImage'
              : field == 'bottomLeft'
              ? 'bottomLeftImage'
              : 'bottomRightImage',
        );
        setState(() {
          if (field == 'background') {
            _backgroundUrl = m['url'];
            _backgroundPath = m['path'];
          }
          if (field == 'bottomLeft') {
            _bottomLeftUrl = m['url'];
            _bottomLeftPath = m['path'];
          }
          if (field == 'bottomRight') {
            _bottomRightUrl = m['url'];
            _bottomRightPath = m['path'];
          }
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      } finally {
        setState(() {
          if (field == 'background') _bgUploading = false;
          if (field == 'bottomLeft') _blUploading = false;
          if (field == 'bottomRight') _brUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Game')),
      body: SingleChildScrollView(
        child: Padding(
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
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Short description shown in the games list',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _instructionsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (optional)',
                    hintText: 'Shown on the game page to participants',
                  ),
                  maxLines: 4,
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
                  title: const Text(
                    'Code-based game (give users unique codes)',
                  ),
                  value: _codeBased,
                  onChanged: (v) => setState(() => _codeBased = v ?? false),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Active (show to users)'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v ?? false),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Allow non-NU IDs to register'),
                  subtitle: const Text(
                    'If enabled, users without NU IDs can sign up',
                  ),
                  value: _allowNonNuIds,
                  onChanged: (v) => setState(() => _allowNonNuIds = v ?? false),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Disable scoreboard for this game'),
                  value: _scoreboardDisabled,
                  onChanged: (v) =>
                      setState(() => _scoreboardDisabled = v ?? false),
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
                // Image upload fields (uploads to Firebase Storage; URL + storage path stored in Firestore)
                _buildImagePickerRow(
                  label: 'Background image (optional)',
                  imageUrl: _backgroundUrl,
                  pickedFile: _backgroundPickedFile,
                  uploading: _bgUploading,
                  onPick: () => _pickImage('background'),
                ),
                const SizedBox(height: 8),
                _buildImagePickerRow(
                  label: 'Bottom-left image (optional)',
                  imageUrl: _bottomLeftUrl,
                  pickedFile: _bottomLeftPickedFile,
                  uploading: _blUploading,
                  onPick: () => _pickImage('bottomLeft'),
                ),
                const SizedBox(height: 8),
                _buildImagePickerRow(
                  label: 'Bottom-right image (optional)',
                  imageUrl: _bottomRightUrl,
                  pickedFile: _bottomRightPickedFile,
                  uploading: _brUploading,
                  onPick: () => _pickImage('bottomRight'),
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
