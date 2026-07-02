import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../models/diary_entry.dart';
import '../services/api_client.dart';
import '../services/diary_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import 'entry_form_screen.dart';

class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen(
      {required this.api,
      required this.repository,
      required this.entry,
      super.key});

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
      MaterialPageRoute(
          builder: (_) => EntryFormScreen(
              api: widget.api,
              repository: widget.repository,
              entryType: _entry.entryType,
              entry: _entry)),
    );
    if (saved != null && mounted) setState(() => _entry = saved);
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await widget.repository.deleteEntry(_entry);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = _entry.imageMedia;
    final videos = _entry.videoMedia;
    final audios = _entry.audioMedia;
    final visualMedia = [
      ...images,
      ...videos,
    ];
    return AppScaffold(
      padding: EdgeInsets.zero,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          actions: [
            IconButton(
                onPressed: _edit,
                icon: const Icon(Icons.edit),
                tooltip: 'Edit'),
            IconButton(
                onPressed: _deleting ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete'),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_entry.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(DateFormat('MMM d, yyyy').format(_entry.entryDate),
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  Chip(
                      label: Text(_entry.entryType == 'full'
                          ? 'Full Diary'
                          : 'Quick Diary')),
                ],
              ),
              if (audios.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...audios.map((media) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AudioPlayerCard(url: media.url),
                    )),
              ],
              if (visualMedia.isNotEmpty) ...[
                const SizedBox(height: 12),
                _MediaStackGallery(media: visualMedia),
              ],
              const SizedBox(height: 18),
              if (_entry.entryType == 'full')
                SoftCard(
                    child: Text(_entry.content ?? '',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.45)))
              else
                SoftCard(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Fact(label: 'Mood', value: _entry.mood ?? '-'),
                    _Fact(label: 'Energy', value: '${_entry.energy ?? '-'}'),
                    _Fact(
                        label: 'Best Moment', value: _entry.bestMoment ?? '-'),
                    _Fact(
                        label: 'Biggest Challenge',
                        value: _entry.challenge ?? '-'),
                  ],
                )),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaStackGallery extends StatelessWidget {
  const _MediaStackGallery({required this.media});

  final List<EntryMedia> media;

  @override
  Widget build(BuildContext context) {
    final first = media.first;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _FullscreenMediaViewer(media: media))),
      child: SizedBox(
        height: 260,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (media.length > 2)
              Positioned(
                left: 28,
                right: 28,
                top: 20,
                bottom: 0,
                child: _StackShadowLayer(
                    color: AppTheme.primary.withValues(alpha: 0.18)),
              ),
            if (media.length > 1)
              Positioned(
                left: 14,
                right: 14,
                top: 10,
                bottom: 6,
                child: _StackShadowLayer(
                    color: Colors.black.withValues(alpha: 0.08)),
              ),
            Positioned.fill(
              child: Hero(
                tag: 'entry-media-${first.url}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _MediaPreview(media: first),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      media.any((item) => item.mediaType == 'video')
                          ? Icons.collections_outlined
                          : Icons.photo_library_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text('${media.length}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Color(0x8C000000),
                    borderRadius: BorderRadius.all(Radius.circular(999))),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    children: [
                      Icon(Icons.swipe, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Tap to view',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackShadowLayer extends StatelessWidget {
  const _StackShadowLayer({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.media});

  final EntryMedia media;

  @override
  Widget build(BuildContext context) {
    if (media.mediaType == 'video') {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF111827)),
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 68),
          ),
        ],
      );
    }
    return Image.network(
      media.url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }
}

class _FullscreenMediaViewer extends StatefulWidget {
  const _FullscreenMediaViewer({required this.media});

  final List<EntryMedia> media;

  @override
  State<_FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<_FullscreenMediaViewer> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.media.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.media.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) {
          final item = widget.media[index];
          if (item.mediaType == 'video') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _VideoPlayerCard(url: item.url, darkMode: true),
              ),
            );
          }
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Hero(
                tag: index == 0 ? 'entry-media-${item.url}' : item.url,
                child: Image.network(
                  item.url,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AudioPlayerCard extends StatefulWidget {
  const _AudioPlayerCard({required this.url});

  final String url;

  @override
  State<_AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<_AudioPlayerCard> {
  late final AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.durationStream.listen((duration) {
      if (mounted && duration != null) setState(() => _duration = duration);
    });
    _player.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      await _player.setUrl(widget.url);
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: _error != null
          ? const Text('Audio could not be loaded.',
              style: TextStyle(fontWeight: FontWeight.w800))
          : Row(
              children: [
                IconButton.filled(
                  onPressed: _loading
                      ? null
                      : () async {
                          if (_player.playing) {
                            await _player.pause();
                          } else {
                            await _player.play();
                          }
                          if (mounted) setState(() {});
                        },
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_player.playing ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Audio note',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      Slider(
                        value: _duration.inMilliseconds == 0
                            ? 0
                            : _position.inMilliseconds
                                .clamp(0, _duration.inMilliseconds)
                                .toDouble(),
                        max: _duration.inMilliseconds == 0
                            ? 1
                            : _duration.inMilliseconds.toDouble(),
                        onChanged: _loading
                            ? null
                            : (value) => _player
                                .seek(Duration(milliseconds: value.round())),
                      ),
                      Text(
                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
  const _VideoPlayerCard({required this.url, this.darkMode = false});

  final String url;
  final bool darkMode;

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
    final child = FutureBuilder<void>(
      future: _initialize,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
              height: 190, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || _controller.value.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Video could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(widget.url,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
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
                aspectRatio: _controller.value.aspectRatio == 0
                    ? 16 / 9
                    : _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _controller.value.isPlaying ? 0 : 1,
                        duration: const Duration(milliseconds: 160),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.52),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 34),
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
                child: VideoProgressIndicator(_controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                        playedColor: AppTheme.primary)),
              ),
            ],
          ),
        );
      },
    );
    if (widget.darkMode) {
      return child;
    }
    return SoftCard(
      padding: EdgeInsets.zero,
      child: child,
    );
  }
}
