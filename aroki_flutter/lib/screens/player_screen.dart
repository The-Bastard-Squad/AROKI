import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/connector_models.dart';
import '../state/aroki_app_state.dart';
import '../theme/aroki_theme.dart';

class PlayerScreen extends StatefulWidget {
  final CatalogItem titleItem;
  final EpisodeItem episode;
  final String variant;

  const PlayerScreen({
    super.key,
    required this.titleItem,
    required this.episode,
    required this.variant,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  List<StreamCandidate> _streamCandidates = [];
  StreamCandidate? _selectedCandidate;
  SubtitleTrack? _selectedSubtitle;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStreamAndInitialize();
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _loadStreamAndInitialize() async {
    final state = Provider.of<ArokiAppState>(context, listen: false);
    final manifest = state.activeManifest;

    if (manifest == null) {
      setState(() {
        _isLoading = false;
        _error = 'No active manifest loaded';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final streamsOp = manifest.operations['streams'] as Map<String, dynamic>?;
      if (streamsOp != null) {
        final candidates = await state.engine.fetchStreams(
          streamsOp,
          titleID: widget.titleItem.sourceID,
          episodeID: widget.episode.episodeID,
          variant: widget.variant,
        );

        if (candidates.isEmpty) {
          setState(() {
            _error = 'No playable stream candidate returned by source.';
            _isLoading = false;
          });
          return;
        }

        _streamCandidates = candidates;
        _selectedCandidate = candidates.first;
        if (_selectedCandidate!.subtitles.isNotEmpty) {
          _selectedSubtitle = _selectedCandidate!.subtitles.first;
        }

        await _initializePlayer(_selectedCandidate!);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _initializePlayer(StreamCandidate candidate) async {
    _chewieController?.dispose();
    await _videoPlayerController?.dispose();

    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(candidate.url),
      formatHint: _videoFormatFor(candidate),
      httpHeaders: candidate.headers ?? {},
    );

    try {
      await _videoPlayerController!.initialize();
    } catch (e) {
      await _videoPlayerController?.dispose();
      _videoPlayerController = null;
      if (!mounted) return;
      setState(() {
        _error =
            'Unable to play ${candidate.qualityLabel} stream (${candidate.mediaTypeHint}). $e';
        _isLoading = false;
      });
      return;
    }

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController!.value.aspectRatio > 0
          ? _videoPlayerController!.value.aspectRatio
          : 16 / 9,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: ArokiTheme.accent,
        handleColor: ArokiTheme.accent,
        backgroundColor: ArokiTheme.cardBorder,
        bufferedColor: ArokiTheme.textMuted,
      ),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  VideoFormat? _videoFormatFor(StreamCandidate candidate) {
    final hint = candidate.mediaTypeHint.toLowerCase().trim();
    final urlPath = Uri.tryParse(candidate.url)?.path.toLowerCase() ??
        candidate.url.toLowerCase();

    if (hint.contains('hls') ||
        hint.contains('m3u8') ||
        urlPath.endsWith('.m3u8')) {
      return VideoFormat.hls;
    }
    if (hint.contains('dash') ||
        hint.contains('mpd') ||
        urlPath.endsWith('.mpd')) {
      return VideoFormat.dash;
    }
    if (hint.contains('smooth') || hint == 'ss' || urlPath.endsWith('.ism')) {
      return VideoFormat.ss;
    }
    if (hint.contains('mp4') || hint.contains('progressive')) {
      return VideoFormat.other;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.titleItem.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.episode.title} (${widget.variant.toUpperCase()})',
              style: const TextStyle(
                  fontSize: 12, color: ArokiTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          if (_streamCandidates.length > 1)
            PopupMenuButton<StreamCandidate>(
              icon: const Icon(CupertinoIcons.gear_alt, color: Colors.white),
              onSelected: (candidate) async {
                setState(() {
                  _selectedCandidate = candidate;
                  _isLoading = true;
                });
                await _initializePlayer(candidate);
              },
              itemBuilder: (context) => _streamCandidates
                  .map(
                    (c) => PopupMenuItem<StreamCandidate>(
                      value: c,
                      child: Text(
                          'Quality: ${c.qualityLabel} (${c.mediaTypeHint})'),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _isLoading
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: ArokiTheme.accent),
                          SizedBox(height: 16),
                          Text(
                            'Loading stream & subtitles...',
                            style: TextStyle(
                                color: ArokiTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      )
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                    CupertinoIcons
                                        .exclamationmark_triangle_fill,
                                    color: Colors.orangeAccent,
                                    size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadStreamAndInitialize,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: ArokiTheme.accent),
                                  child: const Text('Retry Stream',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : _chewieController != null &&
                                _chewieController!
                                    .videoPlayerController.value.isInitialized
                            ? Chewie(controller: _chewieController!)
                            : const Text('Initializing player...',
                                style: TextStyle(color: Colors.white)),
              ),
            ),
            if (_selectedCandidate != null &&
                _selectedCandidate!.subtitles.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: ArokiTheme.cardBackground,
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.captions_bubble_fill,
                        color: ArokiTheme.accent, size: 20),
                    const SizedBox(width: 8),
                    const Text('Subtitles: ',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<SubtitleTrack>(
                        value: _selectedSubtitle,
                        dropdownColor: ArokiTheme.cardBackground,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        items: _selectedCandidate!.subtitles
                            .map(
                              (sub) => DropdownMenuItem(
                                value: sub,
                                child:
                                    Text('${sub.label} (${sub.languageCode})'),
                              ),
                            )
                            .toList(),
                        onChanged: (newSub) {
                          setState(() {
                            _selectedSubtitle = newSub;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
