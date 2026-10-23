import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/diary_entry.dart';
import '../services/api_client.dart';
import '../services/diary_repository.dart';
import '../services/media_encryption_service.dart';
import '../services/media_playback_source.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/encrypted_media_image.dart';
import 'entry_form_screen.dart';

Future<void> _openDownloadUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Could not open media.')));
  }
}

Future<void> _downloadMedia(BuildContext context, EntryMedia media) async {
  if (!media.encrypted) {
    await _openDownloadUrl(context, media.url);
    return;
  }
  try {
    final bytes = await MediaEncryptionService.instance.decryptMedia(media);
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType: media.contentType,
        name: 'safar-${media.mediaType}${extensionFor(media)}',
      )
    ]);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

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
  List<Map<String, dynamic>> _mentionedBy = [];
  String? _connectionsError;
  bool _deleting = false;
  bool _summarizing = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    try {
      final items = await widget.api.connections(_entry.id);
      if (mounted) {
        setState(() {
          _mentionedBy = items;
          _connectionsError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _connectionsError =
            'Connections could not be loaded. Tap to retry.');
      }
    }
  }

  Future<void> _openReference(String id) async {
    try {
      final entry = await widget.api.entry(id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EntryDetailScreen(
              api: widget.api, repository: widget.repository, entry: entry)));
      await _loadConnections();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'This entry is unavailable. Refresh your diary and try again.')));
      }
    }
  }

  Widget _connections() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_entry.references.isNotEmpty) ...[
          Text('Connected memories',
              style: Theme.of(context).textTheme.titleLarge),
          for (final ref in _entry.references)
            Card(
                child: ListTile(
                    leading: Icon(ref.targetEntryId == null
                        ? Icons.link_off
                        : Icons.history),
                    title: Text(ref.targetTitle),
                    subtitle: Text(
                        '${DateFormat.yMMMd().format(ref.targetDate)}${ref.targetEntryId == null ? ' · Entry deleted' : ''}${ref.note == null ? '' : '\n${ref.note}'}'),
                    trailing: ref.targetEntryId == null
                        ? null
                        : const Icon(Icons.chevron_right),
                    onTap: ref.targetEntryId == null
                        ? null
                        : () => _openReference(ref.targetEntryId!))),
        ],
        if (_mentionedBy.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Mentioned in', style: Theme.of(context).textTheme.titleLarge),
          for (final item in _mentionedBy)
            Card(
                child: ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(item['title'] as String),
                    subtitle: Text(
                        '${DateFormat.yMMMd().format(DateTime.parse(item['entry_date'] as String))}${item['note'] == null ? '' : '\n${item['note']}'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openReference(item['id'] as String))),
        ],
        if (_connectionsError != null)
          TextButton(
              onPressed: _loadConnections, child: Text(_connectionsError!)),
      ]);

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<DiaryEntry>(
      MaterialPageRoute(
          builder: (_) => EntryFormScreen(
              api: widget.api,
              repository: widget.repository,
              entryType: _entry.entryType,
              entry: _entry)),
    );
    if (saved != null && mounted) {
      setState(() => _entry = saved);
      await _loadConnections();
    }
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

  Future<void> _summarize() async {
    final text = _summaryText();
    if (text.trim().isEmpty) return;
    setState(() => _summarizing = true);
    try {
      final summary = await widget.api.summarizeDiary(text);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Summary',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 10),
                Text(summary, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  String _summaryText() {
    if (_entry.entryType == 'full') return _entry.content ?? '';
    return [
      if (_entry.mood != null) 'Mood: ${_entry.mood}',
      if (_entry.bestMoment != null) 'Best moment: ${_entry.bestMoment}',
      if (_entry.challenge != null) 'Challenge: ${_entry.challenge}',
    ].join('\n');
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      DateFormat('MMM d, yyyy').format(_entry.entryDate),
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  Chip(
                    label: Text(_entry.entryType == 'full'
                        ? 'Full Diary'
                        : 'Quick Diary'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _summarizing ? null : _summarize,
                    icon: _summarizing
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Summarize'),
                  ),
                ],
              ),
              if (audios.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...audios.map((media) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AudioPlayerCard(media: media),
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
              const SizedBox(height: 20),
              _connections(),
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
    return EncryptedMediaImage(media: media, fit: BoxFit.cover);
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
        actions: [
          IconButton(
            onPressed: () => _downloadMedia(context, widget.media[_index]),
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download',
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.media.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) {
          final item = widget.media[index];
          return LayoutBuilder(
            builder: (context, constraints) {
              final size = MediaQuery.sizeOf(context);
              final maxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : size.width;
              final maxHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : size.height;
              if (item.mediaType == 'video') {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        maxHeight: maxHeight,
                      ),
                      child: _VideoPlayerCard(media: item, darkMode: true),
                    ),
                  ),
                );
              }
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: SizedBox(
                    width: maxWidth,
                    height: maxHeight,
                    child: Hero(
                      tag: index == 0 ? 'entry-media-${item.url}' : item.url,
                      child:
                          EncryptedMediaImage(media: item, fit: BoxFit.contain),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BoundedVideoFrame extends StatelessWidget {
  const _BoundedVideoFrame({
    required this.aspectRatio,
    required this.child,
  });

  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = MediaQuery.sizeOf(context).width;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : fallbackWidth;
        final fallbackHeight = width / aspectRatio;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : fallbackHeight;
        final fittedWidth =
            height * aspectRatio > width ? width : height * aspectRatio;
        final fittedHeight = fittedWidth / aspectRatio;
        return Center(
          child: SizedBox(
            width: fittedWidth,
            height: fittedHeight,
            child: child,
          ),
        );
      },
    );
  }
}

class _AudioPlayerCard extends StatefulWidget {
  const _AudioPlayerCard({required this.media});

  final EntryMedia media;

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
      await setAudioSource(_player, widget.media);
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
                IconButton(
                  onPressed: () => _downloadMedia(context, widget.media),
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download audio',
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
  const _VideoPlayerCard({required this.media, this.darkMode = false});

  final EntryMedia media;
  final bool darkMode;

  @override
  State<_VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<_VideoPlayerCard> {
  VideoPlayerController? _controller;
  late final Future<void> _initialize;

  @override
  void initState() {
    super.initState();
    _initialize = _setup();
  }

  Future<void> _setup() async {
    _controller = await createVideoController(widget.media);
    await _controller!.initialize();
    await _controller!.setLooping(false);
  }

  @override
  void dispose() {
    _controller?.dispose();
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
        if (snapshot.hasError || (_controller?.value.hasError ?? false)) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Video could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(widget.media.url,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          );
        }
        final controller = _controller;
        if (controller == null) {
          return const SizedBox(
              height: 190, child: Center(child: CircularProgressIndicator()));
        }
        final aspectRatio = controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio;
        return _BoundedVideoFrame(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          controller.value.isPlaying
                              ? controller.pause()
                              : controller.play();
                        });
                      },
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: controller.value.isPlaying ? 0 : 1,
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
                  child: VideoProgressIndicator(controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                          playedColor: AppTheme.primary)),
                ),
              ],
            ),
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
