import 'package:flutter/foundation.dart';
import '../models/connector_models.dart';
import '../services/repository_fetcher_service.dart';
import '../services/declarative_extraction_engine.dart';

class ArokiAppState extends ChangeNotifier {
  final RepositoryFetcherService fetcherService = RepositoryFetcherService();
  final DeclarativeExtractionEngine engine = DeclarativeExtractionEngine();

  String _currentRepository = 'kas021/AROKI-Connectors';
  RepositoryIndex? _repoIndex;
  RepositoryConnectorEntry? _activeConnectorEntry;
  ConnectorManifest? _activeManifest;
  bool _isLoadingRepo = false;
  String? _repoError;
  final List<CatalogItem> _savedTitles = [];
  final List<CatalogItem> _recentTitles = [];
  final List<LibraryPlaybackItem> _playbackHistory = [];

  String get currentRepository => _currentRepository;
  RepositoryIndex? get repoIndex => _repoIndex;
  RepositoryConnectorEntry? get activeConnectorEntry => _activeConnectorEntry;
  ConnectorManifest? get activeManifest => _activeManifest;
  bool get isLoadingRepo => _isLoadingRepo;
  String? get repoError => _repoError;
  List<CatalogItem> get savedTitles => List.unmodifiable(_savedTitles);
  List<CatalogItem> get recentTitles => List.unmodifiable(_recentTitles);
  List<LibraryPlaybackItem> get playbackHistory =>
      List.unmodifiable(_playbackHistory);

  ArokiAppState() {
    loadRepository(_currentRepository);
  }

  Future<void> loadRepository(String repo) async {
    _currentRepository = repo;
    _isLoadingRepo = true;
    _repoError = null;
    notifyListeners();

    try {
      _repoIndex = await fetcherService.fetchRepositoryIndex(repo);
      if (_repoIndex != null && _repoIndex!.connectors.isNotEmpty) {
        final active = _repoIndex!.connectors.firstWhere(
          (c) => c.status == 'active',
          orElse: () => _repoIndex!.connectors.first,
        );
        await selectConnector(active);
      }
    } catch (e) {
      _repoError = e.toString();
    } finally {
      _isLoadingRepo = false;
      notifyListeners();
    }
  }

  Future<void> selectConnector(RepositoryConnectorEntry entry) async {
    _activeConnectorEntry = entry;
    notifyListeners();

    try {
      _activeManifest = await fetcherService.fetchConnectorManifest(
        repoOrBaseUrl: _currentRepository,
        manifestInfo: entry.manifest,
      );
    } catch (e) {
      _activeManifest = null;
    }
    notifyListeners();
  }

  bool isTitleSaved(CatalogItem item) {
    return _savedTitles.any((saved) => saved.sourceID == item.sourceID);
  }

  void toggleSavedTitle(CatalogItem item) {
    final existingIndex =
        _savedTitles.indexWhere((saved) => saved.sourceID == item.sourceID);
    if (existingIndex >= 0) {
      _savedTitles.removeAt(existingIndex);
    } else {
      _savedTitles.insert(0, item);
    }
    notifyListeners();
  }

  void markTitleViewed(CatalogItem item) {
    _recentTitles.removeWhere((recent) => recent.sourceID == item.sourceID);
    _recentTitles.insert(0, item);
    if (_recentTitles.length > 20) {
      _recentTitles.removeRange(20, _recentTitles.length);
    }
    notifyListeners();
  }

  void recordPlayback({
    required CatalogItem title,
    required EpisodeItem episode,
    required String variant,
  }) {
    _playbackHistory.removeWhere(
      (item) =>
          item.title.sourceID == title.sourceID &&
          item.episode.episodeID == episode.episodeID &&
          item.variant == variant,
    );
    _playbackHistory.insert(
      0,
      LibraryPlaybackItem(
        title: title,
        episode: episode,
        variant: variant,
        watchedAt: DateTime.now(),
      ),
    );
    if (_playbackHistory.length > 30) {
      _playbackHistory.removeRange(30, _playbackHistory.length);
    }
    markTitleViewed(title);
  }
}

class LibraryPlaybackItem {
  final CatalogItem title;
  final EpisodeItem episode;
  final String variant;
  final DateTime watchedAt;

  LibraryPlaybackItem({
    required this.title,
    required this.episode,
    required this.variant,
    required this.watchedAt,
  });
}
