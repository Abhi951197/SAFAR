import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();

  DateTime _entryDate = DateTime.now();
  String? _mood;
  int _energy = 5;
  XFile? _imageFile;
  XFile? _videoFile;
  XFile? _audioFile;
  String? _imageUrl;
  String? _imagePublicId;
  String? _videoUrl;
  String? _videoPublicId;
  String? _audioUrl;
  String? _audioPublicId;
  bool _saving = false;
  bool _recording = false;
  Timer? _recordingTimer;

  bool get _isFull => widget.entryType == 'full';
  late DiaryEntry? _initialEntry;

  @override
  void initState() {
    super.initState();
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
      _imageUrl = entry.imageUrl;
      _imagePublicId = entry.imagePublicId;
      _videoUrl = entry.videoUrl;
      _videoPublicId = entry.videoPublicId;
      _audioUrl = entry.audioUrl;
      _audioPublicId = entry.audioPublicId;
    } else if (!_isFull) {
      _title.text = 'Quick diary';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _bestMoment.dispose();
    _challenge.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (picked != null) setState(() => _imageFile = picked);
  }

  Future<void> _captureVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 10));
    if (picked != null) setState(() => _videoFile = picked);
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required.')));
      return;
    }
    await _recorder.start(const RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc, bitRate: 96000), path: await _audioPath());
    setState(() => _recording = true);
    _recordingTimer?.cancel();
    _recordingTimer = Timer(const Duration(seconds: 10), _stopRecording);
  }

  Future<String> _audioPath() async {
    final filename = 'safar-audio-${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'webm' : 'm4a'}';
    if (kIsWeb) return filename;
    final directory = await getTemporaryDirectory();
    return '${directory.path}/$filename';
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (path != null) _audioFile = XFile(path, name: 'safar-audio.${kIsWeb ? 'webm' : 'm4a'}');
    });
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
      if (_imageFile != null) {
        final uploaded = await widget.api.uploadImage(_imageFile!);
        _imageUrl = uploaded['image_url'];
        _imagePublicId = uploaded['image_public_id'];
      }
      if (_videoFile != null) {
        final uploaded = await widget.api.uploadVideo(_videoFile!);
        _videoUrl = uploaded['url'];
        _videoPublicId = uploaded['public_id'];
      }
      if (_audioFile != null) {
        final uploaded = await widget.api.uploadAudio(_audioFile!);
        _audioUrl = uploaded['url'];
        _audioPublicId = uploaded['public_id'];
      }
      final payload = {
        'title': _title.text.trim(),
        'content': _isFull ? _content.text.trim() : null,
        'entry_type': widget.entryType,
        'mood': _isFull ? null : _mood,
        'energy': _isFull ? null : _energy,
        'best_moment': _isFull ? null : _bestMoment.text.trim(),
        'challenge': _isFull ? null : _challenge.text.trim(),
        'image_url': _imageUrl,
        'image_public_id': _imagePublicId,
        'video_url': _videoUrl,
        'video_public_id': _videoPublicId,
        'audio_url': _audioUrl,
        'audio_public_id': _audioPublicId,
        'entry_date': DateFormat('yyyy-MM-dd').format(_entryDate),
      };
      if (_initialEntry == null) {
        final saved = await widget.repository.createEntry(payload);
        if (mounted) Navigator.of(context).pop(saved);
      } else {
        final saved = await widget.repository.updateEntry(_initialEntry!.id, payload);
        if (mounted) Navigator.of(context).pop(saved);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final title = _initialEntry == null ? (_isFull ? 'Full Diary' : 'Quick Diary') : 'Edit Entry';
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
              child: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
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
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Title required' : null,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _selectDate,
                          icon: const Icon(Icons.event),
                          label: Text(DateFormat('MMM d, yyyy').format(_entryDate)),
                        ),
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
                      Text('Memories', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      _ImagePreview(imageFile: _imageFile, imageUrl: _imageUrl),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          MediaPill(icon: Icons.image_outlined, label: 'Image', onTap: _pickImage, selected: _imageFile != null || _imageUrl != null),
                          const SizedBox(width: 8),
                          MediaPill(icon: Icons.videocam_outlined, label: 'Video 10s', onTap: _captureVideo, selected: _videoFile != null || _videoUrl != null),
                          const SizedBox(width: 8),
                          MediaPill(icon: _recording ? Icons.stop_circle_outlined : Icons.mic_none, label: _recording ? 'Stop' : 'Audio 10s', onTap: _toggleRecording, selected: _audioFile != null || _audioUrl != null || _recording),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _MediaStatus(videoFile: _videoFile, videoUrl: _videoUrl, audioFile: _audioFile, audioUrl: _audioUrl, recording: _recording),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.check), label: const Text('Save Entry')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fullDiaryFields() {
    return TextFormField(
      controller: _content,
      minLines: 7,
      maxLines: 12,
      decoration: const InputDecoration(labelText: 'What is on your mind?', alignLabelWithHint: true),
      validator: (value) => value == null || value.trim().isEmpty ? 'Content required' : null,
    );
  }

  Widget _quickDiaryFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How was your mood today?', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: ['Very sad', 'Sad', 'Okay', 'Good', 'Great'].map((mood) {
            final selected = _mood == mood;
            final label = {'Very sad': 'Low', 'Sad': 'Sad', 'Okay': 'Ok', 'Good': 'Good', 'Great': 'Best'}[mood]!;
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
                    color: selected ? AppTheme.primary.withValues(alpha: 0.14) : Colors.white,
                    border: Border.all(color: selected ? AppTheme.primary : AppTheme.border, width: selected ? 2 : 1),
                  ),
                  child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: selected ? AppTheme.primary : AppTheme.textSecondary)),
                ),
              ),
            );
          }).toList(),
        ),
        if (_mood == null) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Mood required', style: TextStyle(color: Colors.red))),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Energy Level', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text('$_energy/10', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800)),
          ],
        ),
        Slider(value: _energy.toDouble(), min: 1, max: 10, divisions: 9, label: '$_energy', onChanged: (value) => setState(() => _energy = value.round())),
        const SizedBox(height: 10),
        TextFormField(controller: _bestMoment, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Best moment of the day')),
        const SizedBox(height: 14),
        TextFormField(controller: _challenge, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'What was your biggest challenge?')),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({this.imageFile, this.imageUrl});

  final XFile? imageFile;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageFile == null && imageUrl == null) {
      return Container(
        height: 140,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
        child: const Center(child: Icon(Icons.add_photo_alternate_outlined, color: AppTheme.textSecondary)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: imageFile != null
            ? FutureBuilder(
                future: imageFile!.readAsBytes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                },
              )
            : Image.network(imageUrl!, fit: BoxFit.cover),
      ),
    );
  }
}

class _MediaStatus extends StatelessWidget {
  const _MediaStatus({
    this.videoFile,
    this.videoUrl,
    this.audioFile,
    this.audioUrl,
    required this.recording,
  });

  final XFile? videoFile;
  final String? videoUrl;
  final XFile? audioFile;
  final String? audioUrl;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (videoFile != null || videoUrl != null) {
      items.add(const _StatusChip(icon: Icons.videocam, text: 'Video attached'));
    }
    if (recording) {
      items.add(const _StatusChip(icon: Icons.fiber_manual_record, text: 'Recording, max 10s'));
    } else if (audioFile != null || audioUrl != null) {
      items.add(const _StatusChip(icon: Icons.mic, text: 'Audio attached'));
    }
    if (items.isEmpty) {
      return const Text('Add one image, one short video, and one 10s audio note.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12));
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
