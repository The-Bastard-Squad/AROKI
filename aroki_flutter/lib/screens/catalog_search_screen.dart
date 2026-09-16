import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/connector_models.dart';
import '../state/aroki_app_state.dart';
import '../theme/aroki_theme.dart';
import 'detail_screen.dart';

class CatalogSearchScreen extends StatefulWidget {
  const CatalogSearchScreen({super.key});

  @override
  State<CatalogSearchScreen> createState() => _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends State<CatalogSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<CatalogItem> _items = [];
  final Set<String> _seenSourceIDs = <String>{};
  List<Map<String, dynamic>> _sections = const [];

  int _sectionIndex = 0;
  int _page = 0;
  String? _query;
  String? _error;
  String? _activeConnectorID;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  late final VoidCallback _manifestListener;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    final state = context.read<ArokiAppState>();
    _activeConnectorID = state.activeConnectorEntry?.id;
    _manifestListener = () => _onManifestChanged(state);
    state.addListener(_manifestListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applySections(state.activeManifest);
      _reload();
    });
  }

  @override
  void dispose() {
    context.read<ArokiAppState>().removeListener(_manifestListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isSearching => _query != null && _query!.trim().isNotEmpty;

  void _onManifestChanged(ArokiAppState state) {
    final nextID = state.activeConnectorEntry?.id;
    if (nextID == _activeConnectorID) return;
    _activeConnectorID = nextID;
    _applySections(state.activeManifest);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }
  }

  void _applySections(ConnectorManifest? manifest) {
    final discoveryOp =
        manifest?.operations['discovery'] as Map<String, dynamic>?;
    final rawSections = discoveryOp?['sections'] as List<dynamic>? ?? const [];
    _sections = rawSections.whereType<Map<String, dynamic>>().toList();
    if (_sectionIndex >= _sections.length) _sectionIndex = 0;
  }

  bool _supportsPagination(
      Map<String, dynamic>? sectionDef, Map<String, dynamic>? searchOp) {
    String? urlTemplate;
    if (sectionDef != null) {
      urlTemplate = (sectionDef['request'] as Map<String, dynamic>?)?['urlTemplate']
          ?.toString();
    } else if (searchOp != null) {
      urlTemplate = (searchOp['request'] as Map<String, dynamic>?)?['urlTemplate']
          ?.toString();
    }
    return urlTemplate != null && urlTemplate.contains('{page}');
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final reachedEnd = position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 300;
    if (reachedEnd) _triggerLoadMore();
  }

  void _triggerLoadMore() {
    if (_isLoadingMore || _isInitialLoading || !_hasMore || _error != null) {
      return;
    }
    _loadPage();
  }

  Future<void> _reload() async {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _page = 0;
    _hasMore = true;
    await _loadPage(reset: true);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerLoadMore();
      });
    }
  }

  Future<void> _loadPage({bool reset = false}) async {
    final state = context.read<ArokiAppState>();
    final manifest = state.activeManifest;

    if (manifest == null) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
          if (reset) {
            _error = 'No connector selected yet. Add a verified source in Profile.';
          }
        });
      }
      return;
    }

    setState(() {
      _error = null;
      if (reset) {
        _isInitialLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    final searching = _isSearching;
    Map<String, dynamic>? sectionDef;
    Map<String, dynamic>? searchOp;
    List<CatalogItem> fetched = const [];

    if (searching) {
      searchOp = manifest.operations['search'] as Map<String, dynamic>?;
    } else if (_sectionIndex < _sections.length) {
      sectionDef = _sections[_sectionIndex];
    }

    try {
      if (searching) {
        if (searchOp != null) {
          fetched = await state.engine.fetchSearchResults(
            searchOp,
            _query!.trim(),
            page: _page + 1,
          );
        }
      } else if (sectionDef != null) {
        fetched = await state.engine.fetchDiscoverySection(
          sectionDef,
          page: _page + 1,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
          if (reset || _items.isEmpty) {
            _error = e.toString();
          }
        });
      }
      return;
    }

    if (!mounted) return;

    final supportsPagination = _supportsPagination(sectionDef, searchOp);

    setState(() {
      _page += 1;
      var added = 0;
      if (reset) {
        _items.clear();
        _seenSourceIDs.clear();
      }
      for (final item in fetched) {
        if (_seenSourceIDs.add(item.sourceID)) {
          _items.add(item);
          added += 1;
        }
      }
      final loadedSomething = reset ? _items.isNotEmpty : added > 0;
      _hasMore = fetched.isNotEmpty && supportsPagination && loadedSomething;
      _isInitialLoading = false;
      _isLoadingMore = false;
    });
  }

  Future<void> _performSearch(String term) async {
    final query = term.trim();
    setState(() {
      _query = query.isEmpty ? null : query;
      _searchController.value = TextEditingValue(
        text: term,
        selection: TextSelection.collapsed(offset: term.length),
      );
    });
    FocusManager.instance.primaryFocus?.unfocus();
    await _reload();
  }

  void _clearSearch() {
    setState(() {
      _query = null;
      _searchController.clear();
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ArokiAppState>();
    final connector = state.activeConnectorEntry;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _DiscoverBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(connector?.name),
                _buildSearchField(),
                if (!_isSearching && _sections.length > 1) _buildSectionRail(),
                Expanded(child: _buildContent(state)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String? connectorName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'AROKI',
                      style: TextStyle(
                        color: ArokiTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '•',
                        style: TextStyle(
                          color: ArokiTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        connectorName ?? 'No source',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ArokiTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Discover',
                  style: TextStyle(
                    color: ArokiTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: TextField(
            controller: _searchController,
            onSubmitted: _performSearch,
            style: const TextStyle(color: ArokiTheme.textPrimary, fontSize: 15),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search anime, series or titles…',
              hintStyle: const TextStyle(color: ArokiTheme.textMuted),
              prefixIcon: const Icon(
                CupertinoIcons.search,
                color: ArokiTheme.textSecondary,
                size: 20,
              ),
              suffixIcon: _isSearching
                  ? IconButton(
                      icon: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: ArokiTheme.textSecondary,
                        size: 18,
                      ),
                      onPressed: _clearSearch,
                    )
                  : null,
              filled: true,
              fillColor: ArokiTheme.cardBackground.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              isDense: true,
              border: _searchBorder(ArokiTheme.cardBorder),
              enabledBorder: _searchBorder(ArokiTheme.cardBorder),
              focusedBorder:
                  _searchBorder(ArokiTheme.accent.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ),
    );
  }

  InputBorder _searchBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: 0.8),
    );
  }

  Widget _buildSectionRail() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = _sections[index];
          final selected = index == _sectionIndex;
          return GestureDetector(
            onTap: selected
                ? null
                : () {
                    setState(() => _sectionIndex = index);
                    _reload();
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? ArokiTheme.accent.withValues(alpha: 0.16)
                    : ArokiTheme.cardBackground.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? ArokiTheme.accent.withValues(alpha: 0.45)
                      : ArokiTheme.cardBorder,
                  width: selected ? 1 : 0.8,
                ),
              ),
              child: Text(
                (section['title'] ?? section['id'] ?? 'Section').toString(),
                style: TextStyle(
                  color:
                      selected ? ArokiTheme.accent : ArokiTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(ArokiAppState state) {
    if (state.isLoadingRepo) return const _SkeletonGrid();

    if (_isInitialLoading && _items.isEmpty) return const _SkeletonGrid();

    if (_error != null && _items.isEmpty) {
      return _StatusView(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Something went wrong',
        subtitle: _error!,
        iconColor: Colors.redAccent,
        actionLabel: 'Try Again',
        action: _reload,
      );
    }

    if (_items.isEmpty) {
      return _StatusView(
        icon: _isSearching ? CupertinoIcons.search : CupertinoIcons.antenna_radiowaves_left_right,
        title: _isSearching ? 'No results found' : 'Nothing to show yet',
        subtitle: _isSearching
            ? 'Try a different search term.'
            : 'This source has no discoverable titles right now.',
        iconColor: ArokiTheme.textMuted,
      );
    }

    return RefreshIndicator(
      color: ArokiTheme.accent,
      onRefresh: _reload,
      child: GridView.builder(
        controller: _scrollController,
        physics:
            const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 14,
          childAspectRatio: 0.6,
        ),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) return _buildFooter();
          final item = _items[index];
          return _CatalogCard(
            item: item,
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
      ),
    );
  }

  Widget _buildFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: ArokiTheme.accent,
            ),
          ),
        ),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
children: [
              Icon(
                CupertinoIcons.checkmark_seal_fill,
                size: 14,
                color: ArokiTheme.textMuted,
              ),
              SizedBox(width: 6),
              Text(
                'You’re all caught up',
                style: TextStyle(color: ArokiTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox(height: 40);
  }
}

class _DiscoverBackdrop extends StatelessWidget {
  const _DiscoverBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ArokiTheme.background,
            Color(0xFF0E1220),
            ArokiTheme.background,
          ],
        ),
      ),
      child: Align(
        alignment: const Alignment(1.4, -1.2),
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                ArokiTheme.accent.withValues(alpha: 0.16),
                ArokiTheme.accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  final CatalogItem item;
  final VoidCallback onTap;

  const _CatalogCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSaved =
        context.select<ArokiAppState, bool>((state) => state.isTitleSaved(item));

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: ArokiTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ArokiTheme.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PosterImage(url: item.posterURL),
                  const _PosterGradient(),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _SaveBadge(isSaved: isSaved, item: item),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ArokiTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  final String? url;

  const _PosterImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final hasURL = url != null && url!.isNotEmpty;
    if (!hasURL) return const _PosterFallback();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => const _PosterFallback(),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1F2B), ArokiTheme.cardBackground],
        ),
      ),
      child: const Center(
        child: Icon(CupertinoIcons.film, color: ArokiTheme.textMuted, size: 34),
      ),
    );
  }
}

class _PosterGradient extends StatelessWidget {
  const _PosterGradient();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.35),
            ],
            stops: const [0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

class _SaveBadge extends StatelessWidget {
  final bool isSaved;
  final CatalogItem item;

  const _SaveBadge({required this.isSaved, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<ArokiAppState>().toggleSavedTitle(item),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.8,
          ),
        ),
        child: Icon(
          isSaved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
          size: 13,
          color: isSaved ? ArokiTheme.accent : Colors.white,
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatefulWidget {
  const _SkeletonGrid();

  @override
  State<_SkeletonGrid> createState() => _SkeletonGridState();
}

class _SkeletonGridState extends State<_SkeletonGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.6,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.4, end: 0.9).animate(_controller),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ArokiTheme.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ArokiTheme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 13,
                width: 140,
                decoration: BoxDecoration(
                  color: ArokiTheme.cardBackground,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final String? actionLabel;
  final Future<void> Function()? action;

  const _StatusView({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    this.actionLabel,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(height: 16),
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
                height: 1.4,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: action,
                  style: FilledButton.styleFrom(
                    backgroundColor: ArokiTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  icon: const Icon(CupertinoIcons.arrow_clockwise, size: 16),
                  label: Text(actionLabel ?? 'Try Again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}