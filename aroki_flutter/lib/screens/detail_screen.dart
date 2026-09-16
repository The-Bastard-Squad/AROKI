import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/connector_models.dart';
import '../state/aroki_app_state.dart';
import '../theme/aroki_theme.dart';
import 'player_screen.dart';

class TitleDetailScreen extends StatefulWidget {
  final CatalogItem item;

  const TitleDetailScreen({super.key, required this.item});

  @override
  State<TitleDetailScreen> createState() => _TitleDetailScreenState();
}

class _TitleDetailScreenState extends State<TitleDetailScreen> {
  List<EpisodeItem> _episodes = [];
  bool _isLoading = true;
  String? _error;
  String _selectedVariant = 'sub';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEpisodes();
    });
  }

  Future<void> _loadEpisodes() async {
    final state = Provider.of<ArokiAppState>(context, listen: false);
    final manifest = state.activeManifest;

    if (manifest == null) {
      setState(() {
        _isLoading = false;
        _error = 'No active connector manifest available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final epOp = manifest.operations['episodes'] as Map<String, dynamic>?;
      if (epOp != null) {
        final episodes = await state.engine.fetchEpisodes(epOp, widget.item.sourceID);
        setState(() {
          _episodes = episodes;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.item.posterURL != null && widget.item.posterURL!.isNotEmpty
                      ? Image.network(
                          widget.item.posterURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: ArokiTheme.cardBackground),
                        )
                      : Container(color: ArokiTheme.cardBackground),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, ArokiTheme.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Audio / Variant:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ArokiTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('SUB'),
                        selected: _selectedVariant == 'sub',
                        selectedColor: ArokiTheme.accent,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedVariant = 'sub');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('DUB'),
                        selected: _selectedVariant == 'dub',
                        selectedColor: ArokiTheme.accent,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedVariant = 'dub');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Episodes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ArokiTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: ArokiTheme.accent),
                      ),
                    )
                  else if (_error != null)
                    Text('Error: $_error', style: const TextStyle(color: Colors.redAccent))
                  else if (_episodes.isEmpty)
                    const Text('No episodes listed.', style: TextStyle(color: ArokiTheme.textSecondary))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _episodes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ep = _episodes[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: ArokiTheme.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ArokiTheme.cardBorder),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: ArokiTheme.accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${ep.episodeNumber ?? (index + 1)}',
                                  style: const TextStyle(
                                    color: ArokiTheme.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              ep.title,
                              style: const TextStyle(color: ArokiTheme.textPrimary, fontSize: 14),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.play_circle_fill,
                              color: ArokiTheme.accent,
                              size: 26,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    titleItem: widget.item,
                                    episode: ep,
                                    variant: _selectedVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
