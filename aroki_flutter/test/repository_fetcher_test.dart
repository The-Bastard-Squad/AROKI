import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aroki/services/repository_fetcher_service.dart';

void main() {
  group('Repository Fetcher & Digest Tests', () {
    final service = RepositoryFetcherService();

    test('calculateSha256 and verifyDigest work as expected', () {
      const input = 'hello aroki';
      final bytes = utf8.encode(input);
      final expectedSha = sha256.convert(bytes).toString();

      expect(service.calculateSha256(bytes), expectedSha);
      expect(service.verifyDigest(bytes, expectedSha), isTrue);
      expect(service.verifyDigest(bytes, 'wrong_sha'), isFalse);
    });

    test('parseConnectorManifest verifies SHA-256 digest', () {
      const jsonStr = '{"schemaVersion":1,"id":"anikage","name":"AniKage"}';
      final bytes = utf8.encode(jsonStr);
      final validSha = sha256.convert(bytes).toString();

      final manifest =
          service.parseConnectorManifest(jsonStr, expectedSha256: validSha);
      expect(manifest.id, 'anikage');

      expect(
        () => service.parseConnectorManifest(jsonStr,
            expectedSha256:
                '0000000000000000000000000000000000000000000000000000000000000000'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
