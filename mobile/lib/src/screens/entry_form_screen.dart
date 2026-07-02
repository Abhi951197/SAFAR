import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diary_entry.dart';
import '../services/api_client.dart';
import '../services/diary_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({
    required this.api,
    required this.repository,
    required this.entryType,
    this.entry,
    super.key,
  });

  final ApiClient api;
  final DiaryRepository repository;
  final String entryType;
  final DiaryEntry? entry;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _bestMoment = TextEditingController();
  final _challenge = TextEditingController();
  final _titleFocus = FocusNode();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();

  DateTime _entryDate = DateTime.now();
  String? _mood;
  int _energy = 5;
  final List<XFile> _imageFiles = [];
  final List<XFile> _videoFiles = [];
  XFile? _audioFile;
  List<EntryMedia> _existingMedia = [];
  bool _saving = false;
  bool _recording = false;
  String? _aiAction;
  List<String> _titleSuggestions = [];
  Timer? _recordingTimer;

  bool get _isFull => widget.entryType == 'full';
  late DiaryEntry? _initialEntry;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_refreshSelectionState);
    _content.addListener(_refreshSelectionState);
    _bestMoment.addListener(_refreshSelectionState);
    _challenge.addListener(_refreshSelectionState);
    _initialEntry = widget.entry;
    final entry = _initialEntry;
    if (entry != null) {
      _title.text = entry.title;
      _content.text = entry.content ?? '';
      _bestMoment.text = entry.bestMoment ?? '';
      _challenge.text = entry.challenge ?? '';
      _entryDate = entry.entryDate;
      _mood = entry.mood;
      _energy = entry.energy ?? 5;
      _existingMedia = List<EntryMedia>.from(entry.media);
    } else if (!_isFull) {
      _title.text = 'Quick diary';
    }
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_refreshSelectionState);
    _content.removeListener(_refreshSelectionState);
    _bestMoment.removeListener(_refreshSelectionState);
    _challenge.removeListener(_refreshSelectionState);
    _title.dispose();
    _titleFocus.dispose();
    _content.dispose();
    _bestMoment.dispose();
    _challenge.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _refreshSelectionState() {
    if (mounted) setState(() {});
  }

  Future<void> _pickImages() async {
    final remaining = 10 -
        (_existingMedia.where((item) => item.mediaType == 'image').length +
            _imageFiles.length);
    if (remaining <= 0) {
      _showLimit('You can attach up to 10 images.');
      return;
    }
    final picked =
        await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (picked.isEmpty) {
      return;
    }
    setState(() => _imageFiles.addAll(picked.take(remaining)));
    if (picked.length > remaining) {
      _showLimit('Only the first $remaining image(s) were added.');
    }
  }

  Future<void> _captureImage() async {
    final count =
        _existingMedia.where((item) => item.mediaType == 'image').length +
            _imageFiles.length;
    if (count >= 10) {
      _showLimit('You can attach up to 10 images.');
      return;
    }
    final picked = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
    if (picked != null) {
      setState(() => _imageFiles.add(picked));
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_existingMedia.where((item) => item.mediaType == 'video').length +
            _videoFiles.length >=
        3) {
      _showLimit('You can attach up to 3 videos.');
      return;
    }
    final picked = await _picker.pickVideo(
        source: source, maxDuration: const Duration(seconds: 10));
    if (picked != null) {
      setState(() => _videoFiles.add(picked));
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
      return;
    }
    if (_existingMedia.any((item) => item.mediaType == 'audio') ||
        _audioFile != null) {
      _showLimit('You can attach 1 audio clip.');
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Microphone permission is required.')));
      }
      return;
    }
    await _recorder.start(
        const RecordConfig(
            encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
            bitRate: 96000),
        path: await _audioPath());
    setState(() => _recording = true);
    _recordingTimer?.cancel();
    _recordingTimer = Timer(const Duration(seconds: 10), _stopRecording);
  }

  Future<String> _audioPath() async {
    final filename =
        'safar-audio-${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'webm' : 'm4a'}';
    if (kIsWeb) {
      return filename;
    }
    final directory = await getTemporaryDirectory();
    return '${directory.path}/$filename';
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _recording = false;
      if (path != null) {
        _audioFile =
            XFile(path, name: 'safar-audio.${kIsWeb ? 'webm' : 'm4a'}');
      }
    });
  }

  void _showLimit(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showMediaPicker() async {
    if (_recording) {
      await _toggleRecording();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MediaSheetAction(
                  icon: Icons.photo_library_outlined,
                  label: 'Photos from gallery',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImages();
                  },
                ),
                _MediaSheetAction(
                  icon: Icons.photo_camera_outlined,
                  label: 'Take photo',
                  onTap: () {
                    Navigator.of(context).pop();
                    _captureImage();
                  },
                ),
                _MediaSheetAction(
                  icon: Icons.video_library_outlined,
                  label: 'Video from gallery',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickVideo(ImageSource.gallery);
                  },
                ),
                _MediaSheetAction(
                  icon: Icons.videocam_outlined,
                  label: 'Record video',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickVideo(ImageSource.camera);
                  },
                ),
                _MediaSheetAction(
                  icon: Icons.mic_none,
                  label: 'Record audio',
                  onTap: () {
                    Navigator.of(context).pop();
                    _toggleRecording();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isFull && _mood == null) {
      setState(() {});
      return;
    }
    if (_recording) await _stopRecording();
    setState(() => _saving = true);
    try {
      final media = <EntryMedia>[..._existingMedia];
      for (final file in _imageFiles) {
        final uploaded = await widget.api.uploadImage(file);
        media.add(EntryMedia(
            mediaType: 'image',
            url: uploaded['image_url']!,
            publicId: uploaded['image_public_id'],
            sortOrder: media.length));
      }
      for (final file in _videoFiles) {
        final uploaded = await widget.api.uploadVideo(file);
        media.add(EntryMedia(
            mediaType: 'video',
            url: uploaded['url']!,
            publicId: uploaded['public_id'],
            sortOrder: media.length));
      }
      if (_audioFile != null) {
        final uploaded = await widget.api.uploadAudio(_audioFile!);
        media.removeWhere((item) => item.mediaType == 'audio');
        media.add(EntryMedia(
            mediaType: 'audio',
            url: uploaded['url']!,
            publicId: uploaded['public_id'],
            sortOrder: media.length));
      }
      final orderedMedia = [
        for (var i = 0; i < media.length; i++)
          EntryMedia(
              mediaType: media[i].mediaType,
              url: media[i].url,
              publicId: media[i].publicId,
              sortOrder: i),
      ];
      final firstImage = _firstMedia(orderedMedia, 'image');
      final firstVideo = _firstMedia(orderedMedia, 'video');
      final firstAudio = _firstMedia(orderedMedia, 'audio');
      final payload = {
        'title': _title.text.trim(),
        'content': _isFull ? _content.text.trim() : null,
        'entry_type': widget.entryType,
        'mood': _isFull ? null : _mood,
        'energy': _isFull ? null : _energy,
        'best_moment': _isFull ? null : _bestMoment.text.trim(),
        'challenge': _isFull ? null : _challenge.text.trim(),
        'image_url': firstImage?.url,
        'image_public_id': firstImage?.publicId,
        'video_url': firstVideo?.url,
        'video_public_id': firstVideo?.publicId,
        'audio_url': firstAudio?.url,
        'audio_public_id': firstAudio?.publicId,
        'media': orderedMedia
            .map((item) => {
                  'media_type': item.mediaType,
                  'url': item.url,
                  'public_id': item.publicId,
                  'sort_order': item.sortOrder
                })
            .toList(),
        'entry_date': DateFormat('yyyy-MM-dd').format(_entryDate),
      };
      if (_initialEntry == null) {
        final saved = await widget.repository.createEntry(payload);
        if (mounted) {
          Navigator.of(context).pop(saved);
        }
      } else {
        final saved =
            await widget.repository.updateEntry(_initialEntry!.id, payload);
        if (mounted) {
          Navigator.of(context).pop(saved);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  EntryMedia? _firstMedia(List<EntryMedia> media, String type) {
    for (final item in media) {
      if (item.mediaType == type) return item;
    }
    return null;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _entryDate,
    );
    if (picked != null) setState(() => _entryDate = picked);
  }

  Future<bool> _ensureAiNoticeAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('safar_ai_notice_seen') == true) return true;
    if (!mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI writing privacy'),
        content: const Text(
            'AI features send selected diary text to the AI service only when you tap an AI button.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (accepted == true) {
      await prefs.setBool('safar_ai_notice_seen', true);
      return true;
    }
    return false;
  }

  Future<void> _runAiAction(
      String action, Future<void> Function() callback) async {
    if (_aiAction != null) return;
    if (!await _ensureAiNoticeAccepted()) return;
    setState(() => _aiAction = action);
    try {
      await callback();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is ApiException
                ? error.message
                : 'AI writing is unavailable right now.')));
      }
    } finally {
      if (mounted) setState(() => _aiAction = null);
    }
  }

  String _diaryTextForAi() {
    if (_isFull) {
      return [_title.text.trim(), _content.text.trim()]
          .where((value) => value.isNotEmpty)
          .join('\n\n');
    }
    final parts = <String>[
      if (_title.text.trim().isNotEmpty) 'Title: ${_title.text.trim()}',
      if (_mood != null) 'Mood: $_mood',
      'Energy: $_energy/10',
      if (_bestMoment.text.trim().isNotEmpty)
        'Best moment: ${_bestMoment.text.trim()}',
      if (_challenge.text.trim().isNotEmpty)
        'Challenge: ${_challenge.text.trim()}',
    ];
    return parts.join('\n');
  }

  Future<void> _suggestTitles() async {
    await _runAiAction('titles', () async {
      final text = _diaryTextForAi();
      if (text.trim().isEmpty) {
        _showLimit('Write a little first, then Safar can suggest titles.');
        return;
      }
      final titles = await widget.api.suggestDiaryTitles(text);
      if (!mounted) return;
      setState(() => _titleSuggestions = titles);
    });
  }

  Future<void> _summarize() async {
    await _runAiAction('summary', () async {
      final text = _diaryTextForAi();
      if (text.trim().isEmpty) {
        _showLimit('Write a little first, then Safar can summarize it.');
        return;
      }
      final summary = await widget.api.summarizeDiary(text);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.56,
          minChildSize: 0.32,
          maxChildSize: 0.9,
          builder: (context, scrollController) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Summary',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child:
                          Text(summary, style: const TextStyle(height: 1.45)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: summary));
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _enhanceAll() async {
    final controller = _isFull ? _content : _bestMoment;
    final label = _isFull ? 'diary' : 'best moment';
    await _enhanceController(controller,
        label: label, selectionOnly: false, action: 'enhance_all');
  }

  Future<void> _enhanceController(TextEditingController controller,
      {required String label,
      required bool selectionOnly,
      required String action}) async {
    await _runAiAction(action, () async {
      final selection = controller.selection;
      final hasSelection = selection.isValid &&
          !selection.isCollapsed &&
          selection.start >= 0 &&
          selection.end <= controller.text.length;
      final original = selectionOnly && hasSelection
          ? controller.text.substring(selection.start, selection.end)
          : controller.text.trim();
      if (original.trim().isEmpty) {
        _showLimit(selectionOnly
            ? 'Select text first, then tap Enhance Selection.'
            : 'Write a little first, then Safar can enhance it.');
        return;
      }
      if (selectionOnly && !hasSelection) {
        _showLimit('Select text first, then tap Enhance Selection.');
        return;
      }
      final enhanced = await widget.api.enhanceDiaryText(original);
      if (!mounted) return;
      final replace = await _showEnhancePreview(original, enhanced, label);
      if (replace != true) return;
      final previousValue = controller.value;
      setState(() {
        if (selectionOnly) {
          final next = controller.text
              .replaceRange(selection.start, selection.end, enhanced);
          controller.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(
                offset: selection.start + enhanced.length),
          );
        } else {
          controller.text = enhanced;
        }
      });
      _showUndoAiChange(controller, previousValue);
    });
  }

  void _showUndoAiChange(
      TextEditingController controller, TextEditingValue previousValue) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('AI change applied.'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              setState(() => controller.value = previousValue);
            },
          ),
        ),
      );
  }

  Future<bool?> _showEnhancePreview(
      String original, String enhanced, String label) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Enhance $label'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Original',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              SelectableText(original, style: const TextStyle(height: 1.35)),
              const SizedBox(height: 16),
              const Text('Enhanced',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              SelectableText(enhanced, style: const TextStyle(height: 1.35)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: enhanced));
                Navigator.of(context).pop(false);
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace')),
        ],
      ),
    );
  }

  bool _hasSelection(TextEditingController controller) {
    final selection = controller.selection;
    return selection.isValid &&
        !selection.isCollapsed &&
        selection.start >= 0 &&
        selection.end <= controller.text.length;
  }

  Widget _selectionEnhanceButton(TextEditingController controller) {
    if (!_hasSelection(controller)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: _FloatingEnhancePill(
          busy: _aiAction == 'enhance_selection',
          onPressed: _aiAction == null
              ? () => _enhanceController(controller,
                  label: 'selection',
                  selectionOnly: true,
                  action: 'enhance_selection')
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _initialEntry == null
        ? (_isFull ? 'Full Diary' : 'Quick Diary')
        : 'Edit Entry';
    return AppScaffold(
      showImageBackground: true,
      padding: EdgeInsets.zero,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                GlassPanel(
                  child: Column(
                    children: [
                      TextFormField(
                        focusNode: _titleFocus,
                        controller: _title,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          suffixIcon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: _titleFocus.hasFocus
                                ? IconButton(
                                    key: const ValueKey('suggest-title'),
                                    tooltip: 'Suggest title',
                                    onPressed: _aiAction == null
                                        ? _suggestTitles
                                        : null,
                                    icon: _aiAction == 'titles'
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Icon(Icons.auto_fix_high),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Title required'
                                : null,
                      ),
                      if (_titleSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _titleSuggestions
                                .map((title) => ActionChip(
                                      label: Text(title),
                                      onPressed: () => setState(() {
                                        _title.text = title;
                                        _titleSuggestions = [];
                                      }),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _selectDate,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.event, size: 17),
                              label: FittedBox(
                                child: Text(
                                    DateFormat('MMM d').format(_entryDate)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BlackOutlineButton(
                              label: 'Summarize',
                              busy: _aiAction == 'summary',
                              onPressed: _aiAction == null ? _summarize : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BlackOutlineButton(
                              label: 'Enhance All',
                              busy: _aiAction == 'enhance_all',
                              onPressed: _aiAction == null ? _enhanceAll : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isFull) _fullDiaryFields() else _quickDiaryFields(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Memories',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      _ImagePreviewGrid(
                        imageFiles: _imageFiles,
                        imageUrls: _existingMedia
                            .where((item) => item.mediaType == 'image')
                            .map((item) => item.url)
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showMediaPicker,
                          icon: Icon(_recording
                              ? Icons.stop_circle_outlined
                              : Icons.add_photo_alternate_outlined),
                          label:
                              Text(_recording ? 'Stop recording' : 'Add media'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MediaStatus(
                        imageCount: _existingMedia
                                .where((item) => item.mediaType == 'image')
                                .length +
                            _imageFiles.length,
                        videoCount: _existingMedia
                                .where((item) => item.mediaType == 'video')
                                .length +
                            _videoFiles.length,
                        hasAudio: _existingMedia
                                .any((item) => item.mediaType == 'audio') ||
                            _audioFile != null,
                        recording: _recording,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Entry')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fullDiaryFields() {
    return Column(
      children: [
        TextFormField(
          controller: _content,
          minLines: 7,
          maxLines: 12,
          decoration: const InputDecoration(
              labelText: 'What is on your mind?', alignLabelWithHint: true),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Content required' : null,
        ),
        _selectionEnhanceButton(_content),
      ],
    );
  }

  Widget _quickDiaryFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How was your mood today?',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: ['Very sad', 'Sad', 'Okay', 'Good', 'Great'].map((mood) {
            final selected = _mood == mood;
            final label = {
              'Very sad': 'Low',
              'Sad': 'Sad',
              'Okay': 'Ok',
              'Good': 'Good',
              'Great': 'Best'
            }[mood]!;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _mood = mood),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 46,
                  margin: const EdgeInsets.only(right: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.14)
                        : Colors.white,
                    border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.border,
                        width: selected ? 2 : 1),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textSecondary)),
                ),
              ),
            );
          }).toList(),
        ),
        if (_mood == null)
          const Padding(
              padding: EdgeInsets.only(top: 6),
              child:
                  Text('Mood required', style: TextStyle(color: Colors.red))),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Energy Level',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text('$_energy/10',
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w800)),
          ],
        ),
        Slider(
            value: _energy.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_energy',
            onChanged: (value) => setState(() => _energy = value.round())),
        const SizedBox(height: 10),
        TextFormField(
            controller: _bestMoment,
            minLines: 2,
            maxLines: 4,
            decoration:
                const InputDecoration(labelText: 'Best moment of the day')),
        _selectionEnhanceButton(_bestMoment),
        const SizedBox(height: 14),
        TextFormField(
            controller: _challenge,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'What was your biggest challenge?')),
        _selectionEnhanceButton(_challenge),
      ],
    );
  }
}

class _BlackOutlineButton extends StatelessWidget {
  const _BlackOutlineButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Colors.black),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.auto_awesome, size: 17),
      label: FittedBox(child: Text(label)),
    );
  }
}

class _FloatingEnhancePill extends StatelessWidget {
  const _FloatingEnhancePill({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.auto_fix_high, size: 15),
              const SizedBox(width: 6),
              const Text('Enhance',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePreviewGrid extends StatelessWidget {
  const _ImagePreviewGrid({required this.imageFiles, required this.imageUrls});

  final List<XFile> imageFiles;
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final total = imageUrls.length + imageFiles.length;
    if (total == 0) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: const Center(
            child: Icon(Icons.add_photo_alternate_outlined,
                color: AppTheme.textSecondary)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: total,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemBuilder: (context, index) {
        return ClipOval(
          child: DecoratedBox(
            decoration:
                BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08)),
            child: index < imageUrls.length
                ? Image.network(imageUrls[index], fit: BoxFit.cover)
                : FutureBuilder(
                    future: imageFiles[index - imageUrls.length].readAsBytes(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Image.memory(snapshot.data!, fit: BoxFit.cover);
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _MediaSheetAction extends StatelessWidget {
  const _MediaSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
        foregroundColor: AppTheme.primary,
        child: Icon(icon),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      onTap: onTap,
    );
  }
}

class _MediaStatus extends StatelessWidget {
  const _MediaStatus({
    required this.imageCount,
    required this.videoCount,
    required this.hasAudio,
    required this.recording,
  });

  final int imageCount;
  final int videoCount;
  final bool hasAudio;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (imageCount > 0) {
      items.add(_StatusChip(icon: Icons.image, text: '$imageCount/10 images'));
    }
    if (videoCount > 0) {
      items
          .add(_StatusChip(icon: Icons.videocam, text: '$videoCount/3 videos'));
    }
    if (recording) {
      items.add(const _StatusChip(
          icon: Icons.fiber_manual_record, text: 'Recording, max 10s'));
    } else if (hasAudio) {
      items.add(const _StatusChip(icon: Icons.mic, text: '1/1 audio'));
    }
    if (items.isEmpty) {
      return const Text(
          'Add up to 10 images, 3 short videos, and one 10s audio note.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: items);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: AppTheme.primary),
      label: Text(text),
      side: BorderSide.none,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
    );
  }
}
