import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/connector_models.dart';
import '../state/aroki_app_state.dart';
import '../theme/aroki_theme.dart';
import 'detail_screen.dart';
import 'player_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<ArokiAppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Library',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            Text('Saved titles and watch activity',
                style:
                    TextStyle(fontSize: 12, color: ArokiTheme.textSecondary)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _selectedTab,
              backgroundColor: ArokiTheme.cardBackground,
              thumbColor: ArokiTheme.cardBorder,
              children: const {
                0: _SegmentLabel('Continue'),
                1: _SegmentLabel('Saved'),
                2: _SegmentLabel('History'),
              },
              onValueChanged: (value) {
                if (value != null) {
                  setState(() => _selectedTab = value);
                }
              },
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: switch (_selectedTab) {
                0 => _TitleList(
                    key: const ValueKey('continue'),
                    emptyIcon: CupertinoIcons.play_rectangle,
                    emptyTitle: 'Nothing started yet',
                    emptySubtitle:
                        'Open a title or play an episode and it will appear here.',
                    items: state.recentTitles,
                    trailingBuilder: (item) => _SavedButton(item: item),
                  ),
                1 => _TitleList(
                    key: const ValueKey('saved'),
                    emptyIcon: CupertinoIcons.bookmark,
                    emptyTitle: 'No saved titles',
                    emptySubtitle:
                        'Save shows from their detail page to build your list.',
                    items: state.savedTitles,
                    trailingBuilder: (item) => _SavedButton(item: item),
                  ),
                _ => _HistoryList(
                    key: const ValueKey('history'),
                    items: state.playbackHistory,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  final String text;

  const _SegmentLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: ArokiTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TitleList extends StatelessWidget {
  final List<CatalogItem> items;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final Widget Function(CatalogItem item) trailingBuilder;

  const _TitleList({
    super.key,
    required this.items,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.trailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyLibraryState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return _LibraryTitleTile(
          item: item,
          trailing: trailingBuilder(item),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TitleDetailScreen(item: item),
              ),
            );
          },
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<LibraryPlaybackItem> items;

  const _HistoryList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyLibraryState(
        icon: CupertinoIcons.clock,
        title: 'No watch history',
        subtitle: 'Episodes you play will be listed here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return _LibraryTitleTile(
          item: item.title,
          subtitle:
              '${item.episode.title} (${item.variant.toUpperCase()}) - ${_relativeTime(item.watchedAt)}',
          trailing: const Icon(
            CupertinoIcons.play_circle_fill,
            color: ArokiTheme.accent,
            size: 28,
          ),
          onTap: () {
            context.read<ArokiAppState>().recordPlayback(
                  title: item.title,
                  episode: item.episode,
                  variant: item.variant,
                );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerScreen(
                  titleItem: item.title,
                  episode: item.episode,
                  variant: item.variant,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _relativeTime(DateTime watchedAt) {
    final difference = DateTime.now().difference(watchedAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    return '${difference.inDays}d ago';
  }
}

class _LibraryTitleTile extends StatelessWidget {
  final CatalogItem item;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _LibraryTitleTile({
    required this.item,
    this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ArokiTheme.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ArokiTheme.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _PosterThumb(item: item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ArokiTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle ?? 'Tap to view episodes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ArokiTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterThumb extends StatelessWidget {
  final CatalogItem item;

  const _PosterThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 54,
        height: 76,
        child: item.posterURL != null && item.posterURL!.isNotEmpty
            ? Image.network(
                item.posterURL!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _PosterFallback(),
              )
            : const _PosterFallback(),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ArokiTheme.glassOverlay,
      child: const Icon(
        CupertinoIcons.film,
        color: ArokiTheme.textMuted,
        size: 24,
      ),
    );
  }
}

class _SavedButton extends StatelessWidget {
  final CatalogItem item;

  const _SavedButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final isSaved = context.select<ArokiAppState, bool>(
      (state) => state.isTitleSaved(item),
    );

    return IconButton(
      tooltip: isSaved ? 'Remove from saved' : 'Save title',
      icon: Icon(
        isSaved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
        color: isSaved ? ArokiTheme.accent : ArokiTheme.textSecondary,
      ),
      onPressed: () {
        context.read<ArokiAppState>().toggleSavedTitle(item);
      },
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyLibraryState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: ArokiTheme.textMuted, size: 42),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ArokiTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ArokiTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
