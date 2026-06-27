import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../models/diary_entry.dart';
import '../services/api_client.dart';
import '../services/diary_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import 'entry_form_screen.dart';

class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({required this.api, required this.repository, required this.entry, super.key});

  final ApiClient api;
  final DiaryRepository repository;
  final DiaryEntry entry;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late DiaryEntry _entry;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<DiaryEntry>(
      MaterialPageRoute(builder: (_) => EntryFormScreen(api: widget.api, repository: widget.repository, entryType: _entry.entryType, entry: _entry)),
    );
    if (saved != null && mounted) setState(() => _entry = saved);
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await widget.repository.deleteEntry(_entry);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        actions: [
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit), tooltip: 'Edit'),
          IconButton(onPressed: _deleting ? null : _delete, icon: const Icon(Icons.delete_outline), tooltip: 'Delete'),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_entry.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(DateFormat('MMM d, yyyy').format(_entry.entryDate), style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                Chip(label: Text(_entry.entryType == 'full' ? 'Full Diary' : 'Quick Diary')),
              ],
            ),
            if (_entry.imageUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(_entry.imageUrl!, fit: BoxFit.cover)),
            ],
            if (_entry.videoUrl != null || _entry.audioUrl != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_entry.videoUrl != null) const Chip(avatar: Icon(Icons.videocam, size: 16), label: Text('Video saved')),
                  if (_entry.audioUrl != null) const Chip(avatar: Icon(Icons.mic, size: 16), label: Text('Audio saved')),
                ],
              ),
            ],
            const SizedBox(height: 18),
            if (_entry.entryType == 'full')
              SoftCard(child: Text(_entry.content ?? '', style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45)))
            else
              SoftCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Fact(label: 'Mood', value: _entry.mood ?? '-'),
                  _Fact(label: 'Energy', value: '${_entry.energy ?? '-'}'),
                  _Fact(label: 'Best Moment', value: _entry.bestMoment ?? '-'),
                  _Fact(label: 'Biggest Challenge', value: _entry.challenge ?? '-'),
                ],
              )),
            if (_entry.videoUrl != null) ...[
              const SizedBox(height: 12),
              _VideoPlayerCard(url: _entry.videoUrl!),
            ],
            if (_entry.audioUrl != null) ...[
              const SizedBox(height: 12),
              SoftCard(child: _Fact(label: 'Audio URL', value: _entry.audioUrl!)),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _VideoPlayerCard extends StatefulWidget {
  const _VideoPlayerCard({required this.url});

  final String url;

  @override
  State<_VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<_VideoPlayerCard> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize = _controller.initialize();
    _controller.setLooping(false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: FutureBuilder<void>(
        future: _initialize,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(height: 190, child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || _controller.value.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Video could not be loaded.', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(widget.url, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _controller.value.isPlaying ? _controller.pause() : _controller.play();
                        });
                      },
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _controller.value.isPlaying ? 0 : 1,
                          duration: const Duration(milliseconds: 160),
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.52), shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 34),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(_controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: AppTheme.primary)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
