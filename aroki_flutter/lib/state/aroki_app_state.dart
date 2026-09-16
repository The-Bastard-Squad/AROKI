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

  String get currentRepository => _currentRepository;
  RepositoryIndex? get repoIndex => _repoIndex;
  RepositoryConnectorEntry? get activeConnectorEntry => _activeConnectorEntry;
  ConnectorManifest? get activeManifest => _activeManifest;
  bool get isLoadingRepo => _isLoadingRepo;
  String? get repoError => _repoError;

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
}
