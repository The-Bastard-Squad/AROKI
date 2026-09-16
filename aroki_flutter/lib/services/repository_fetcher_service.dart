import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../models/connector_models.dart';

class RepositoryFetcherService {
  final http.Client _httpClient;

  RepositoryFetcherService({http.Client? client})
      : _httpClient = client ?? http.Client();

  String calculateSha256(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  bool verifyDigest(List<int> bytes, String expectedSha256) {
    final actual = calculateSha256(bytes);
    return actual.toLowerCase() == expectedSha256.toLowerCase();
  }

  RepositoryIndex parseRepositoryIndex(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return RepositoryIndex.fromJson(data);
  }

  ConnectorManifest parseConnectorManifest(
    String jsonString, {
    String? expectedSha256,
  }) {
    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final bytes = utf8.encode(jsonString);
      final isValid = verifyDigest(bytes, expectedSha256);
      if (!isValid) {
        throw Exception(
            'SHA-256 digest mismatch. Expected $expectedSha256 but computed ${calculateSha256(bytes)}');
      }
    }
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return ConnectorManifest.fromJson(data);
  }

  Future<RepositoryIndex> fetchRepositoryIndex(String repoOrUrl) async {
    String url = repoOrUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://raw.githubusercontent.com/$repoOrUrl/main/index.json';
    }
    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch repository index from $url (HTTP ${response.statusCode})');
    }
    return parseRepositoryIndex(response.body);
  }

  Future<ConnectorManifest> fetchConnectorManifest({
    required String repoOrBaseUrl,
    required RepositoryManifestInfo manifestInfo,
  }) async {
    String url;
    if (manifestInfo.path.startsWith('http://') || manifestInfo.path.startsWith('https://')) {
      url = manifestInfo.path;
    } else if (repoOrBaseUrl.startsWith('http://') || repoOrBaseUrl.startsWith('https://')) {
      final base = repoOrBaseUrl.endsWith('/') ? repoOrBaseUrl : '$repoOrBaseUrl/';
      url = Uri.parse(base).resolve(manifestInfo.path).toString();
    } else {
      url = 'https://raw.githubusercontent.com/$repoOrBaseUrl/main/${manifestInfo.path}';
    }

    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch connector manifest from $url (HTTP ${response.statusCode})');
    }

    return parseConnectorManifest(response.body, expectedSha256: manifestInfo.sha256);
  }
}
