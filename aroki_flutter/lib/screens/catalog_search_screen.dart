import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/aroki_app_state.dart';
import '../theme/aroki_theme.dart';
import '../models/connector_models.dart';
import 'detail_screen.dart';

class CatalogSearchScreen extends StatefulWidget {
  const CatalogSearchScreen({super.key});

  @override
  State<CatalogSearchScreen> createState() => _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends State<CatalogSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<CatalogItem> _catalogItems = [];
  bool _isLoading = false;
  String? _error;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDiscovery();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscovery() async {
    final state = Provider.of<ArokiAppState>(context, listen: false);
    final manifest = state.activeManifest;

    if (manifest == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isSearching = false;
    });

    try {
      final discoveryOp = manifest.operations['discovery'] as Map<String, dynamic>?;
      if (discoveryOp != null) {
        final sections = discoveryOp['sections'] as List<dynamic>?;
        if (sections != null && sections.isNotEmpty) {
          final firstSection = sections.first as Map<String, dynamic>;
          final items = await state.engine.fetchDiscoverySection(firstSection);
          setState(() {
            _catalogItems = items;
          });
        }
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

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _loadDiscovery();
      return;
    }

    final state = Provider.of<ArokiAppState>(context, listen: false);
    final manifest = state.activeManifest;
    if (manifest == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isSearching = true;
    });

    try {
      final searchOp = manifest.operations['search'] as Map<String, dynamic>?;
      if (searchOp != null) {
        final items = await state.engine.fetchSearchResults(searchOp, query.trim());
        setState(() {
          _catalogItems = items;
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
    final state = Provider.of<ArokiAppState>(context);
    final activeConnector = state.activeConnectorEntry;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AROKI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            if (activeConnector != null)
              Text(
                'Source: ${activeConnector.name}',
                style: const TextStyle(fontSize: 12, color: ArokiTheme.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_clockwise),
            onPressed: _loadDiscovery,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onSubmitted: _performSearch,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search anime, series or titles...',
                hintStyle: const TextStyle(color: ArokiTheme.textMuted),
                prefixIcon: const Icon(CupertinoIcons.search, color: ArokiTheme.textSecondary, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(CupertinoIcons.clear_fill, color: ArokiTheme.textSecondary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadDiscovery();
                        },
                      )
                    : null,
                filled: true,
                fillColor: ArokiTheme.cardBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ArokiTheme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ArokiTheme.cardBorder),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: ArokiTheme.accent),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'Failed to load content:\n$_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      )
                    : _catalogItems.isEmpty
                        ? Center(
                            child: Text(
                              _isSearching ? 'No results found' : 'No titles available for this source',
                              style: const TextStyle(color: ArokiTheme.textSecondary),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _catalogItems.length,
                            itemBuilder: (context, index) {
                              final item = _catalogItems[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TitleDetailScreen(item: item),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: ArokiTheme.cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: ArokiTheme.cardBorder),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: item.posterURL != null && item.posterURL!.isNotEmpty
                                            ? Image.network(
                                                item.posterURL!,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: ArokiTheme.glassOverlay,
                                                  child: const Icon(CupertinoIcons.film, color: ArokiTheme.textMuted, size: 36),
                                                ),
                                              )
                                            : Container(
                                                color: ArokiTheme.glassOverlay,
                                                child: const Center(
                                                  child: Icon(CupertinoIcons.film, color: ArokiTheme.textMuted, size: 36),
                                                ),
                                              ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: ArokiTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
