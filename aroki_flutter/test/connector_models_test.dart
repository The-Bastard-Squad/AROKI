import 'package:flutter_test/flutter_test.dart';
import 'package:aroki_flutter/models/connector_models.dart';

void main() {
  group('Connector Models Unit Tests', () {
    test('RepositoryIndex correctly parses JSON', () {
      final json = {
        'name': 'AROKI Connectors',
        'repositoryID': 'aroki-connectors',
        'schemaVersion': 1,
        'enabled': true,
        'generatedAt': 1789413964,
        'publicKey': 'BYKainAr2pxVfWxSSQJHG79Xl/mnkTuIl1ujEmR+1V4=',
        'signature': 'test_sig',
        'connectors': [
          {
            'id': 'anikage',
            'familyID': 'anikage',
            'name': 'AniKage (BETA)',
            'version': '0.3.3',
            'minimumAppVersion': '0.1.0',
            'contentType': 'video',
            'language': 'en',
            'contentRating': 'unknown',
            'releaseTrack': 'beta',
            'status': 'active',
            'releaseNotes': 'Test notes',
            'manifest': {
              'path': 'connectors/anikage/connector.json',
              'sha256': '70e5a37f0ea1a97c637f65be7b751be892b64b1bdbf520da70114fa5926fd657',
              'signature': 'sig123'
            }
          }
        ]
      };

      final repo = RepositoryIndex.fromJson(json);
      expect(repo.name, 'AROKI Connectors');
      expect(repo.connectors.length, 1);
      expect(repo.connectors.first.id, 'anikage');
      expect(repo.connectors.first.manifest.sha256,
          '70e5a37f0ea1a97c637f65be7b751be892b64b1bdbf520da70114fa5926fd657');
    });

    test('ConnectorManifest parses operations and allowedHosts correctly', () {
      final json = {
        'schemaVersion': 1,
        'id': 'anikage',
        'familyID': 'anikage',
        'name': 'AniKage (BETA)',
        'version': '0.3.3',
        'minimumAppVersion': '0.1.0',
        'contentType': 'video',
        'language': 'en',
        'releaseTrack': 'beta',
        'status': 'active',
        'allowedHosts': ['anikage.cc', 'og.bakayaro.live'],
        'capabilities': ['discovery', 'search', 'details', 'episodes', 'streams'],
        'operations': {'discovery': {}}
      };

      final manifest = ConnectorManifest.fromJson(json);
      expect(manifest.id, 'anikage');
      expect(manifest.allowedHosts.length, 2);
      expect(manifest.capabilities.contains('streams'), isTrue);
      expect(manifest.operations.containsKey('discovery'), isTrue);
    });
  });
}
