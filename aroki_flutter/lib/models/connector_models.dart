class RepositoryManifestInfo {
  final String path;
  final String sha256;
  final String signature;

  RepositoryManifestInfo({
    required this.path,
    required this.sha256,
    required this.signature,
  });

  factory RepositoryManifestInfo.fromJson(Map<String, dynamic> json) {
    return RepositoryManifestInfo(
      path: json['path'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'sha256': sha256,
        'signature': signature,
      };
}

class RepositoryConnectorEntry {
  final String id;
  final String familyID;
  final String name;
  final String version;
  final String minimumAppVersion;
  final String contentType;
  final String language;
  final String contentRating;
  final String releaseTrack;
  final String status;
  final String releaseNotes;
  final RepositoryManifestInfo manifest;

  RepositoryConnectorEntry({
    required this.id,
    required this.familyID,
    required this.name,
    required this.version,
    required this.minimumAppVersion,
    required this.contentType,
    required this.language,
    required this.contentRating,
    required this.releaseTrack,
    required this.status,
    required this.releaseNotes,
    required this.manifest,
  });

  factory RepositoryConnectorEntry.fromJson(Map<String, dynamic> json) {
    return RepositoryConnectorEntry(
      id: json['id'] as String? ?? '',
      familyID: json['familyID'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
      minimumAppVersion: json['minimumAppVersion'] as String? ?? '0.1.0',
      contentType: json['contentType'] as String? ?? 'video',
      language: json['language'] as String? ?? 'en',
      contentRating: json['contentRating'] as String? ?? 'unknown',
      releaseTrack: json['releaseTrack'] as String? ?? 'stable',
      status: json['status'] as String? ?? 'active',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      manifest: RepositoryManifestInfo.fromJson(
        json['manifest'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class RepositoryIndex {
  final String name;
  final String repositoryID;
  final int schemaVersion;
  final bool enabled;
  final int generatedAt;
  final String publicKey;
  final String signature;
  final List<RepositoryConnectorEntry> connectors;

  RepositoryIndex({
    required this.name,
    required this.repositoryID,
    required this.schemaVersion,
    required this.enabled,
    required this.generatedAt,
    required this.publicKey,
    required this.signature,
    required this.connectors,
  });

  factory RepositoryIndex.fromJson(Map<String, dynamic> json) {
    final list = (json['connectors'] as List<dynamic>?)
            ?.map((e) =>
                RepositoryConnectorEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return RepositoryIndex(
      name: json['name'] as String? ?? '',
      repositoryID: json['repositoryID'] as String? ?? '',
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      enabled: json['enabled'] as bool? ?? true,
      generatedAt: json['generatedAt'] as int? ?? 0,
      publicKey: json['publicKey'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      connectors: list,
    );
  }
}

class ConnectorManifest {
  final int schemaVersion;
  final String id;
  final String familyID;
  final String name;
  final String version;
  final String minimumAppVersion;
  final String contentType;
  final String language;
  final String releaseTrack;
  final String status;
  final List<String> allowedHosts;
  final List<String> capabilities;
  final Map<String, dynamic> operations;
  final String downloadSupport;
  final String? releaseNotes;

  ConnectorManifest({
    required this.schemaVersion,
    required this.id,
    required this.familyID,
    required this.name,
    required this.version,
    required this.minimumAppVersion,
    required this.contentType,
    required this.language,
    required this.releaseTrack,
    required this.status,
    required this.allowedHosts,
    required this.capabilities,
    required this.operations,
    required this.downloadSupport,
    this.releaseNotes,
  });

  factory ConnectorManifest.fromJson(Map<String, dynamic> json) {
    return ConnectorManifest(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      id: json['id'] as String? ?? '',
      familyID: json['familyID'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
      minimumAppVersion: json['minimumAppVersion'] as String? ?? '0.1.0',
      contentType: json['contentType'] as String? ?? 'video',
      language: json['language'] as String? ?? 'en',
      releaseTrack: json['releaseTrack'] as String? ?? 'stable',
      status: json['status'] as String? ?? 'active',
      allowedHosts: (json['allowedHosts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      capabilities: (json['capabilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      operations: (json['operations'] as Map<String, dynamic>?) ?? {},
      downloadSupport: json['downloadSupport'] as String? ?? 'none',
      releaseNotes: json['releaseNotes'] as String?,
    );
  }

  bool isDownloadable([StreamCandidate? stream]) {
    if (downloadSupport.toLowerCase() != 'none') return true;
    return stream?.isProgressiveDownload ?? false;
  }
}

class CatalogItem {
  final String sourceID;
  final String title;
  final String? posterURL;
  final String? synopsis;
  final int? year;

  CatalogItem({
    required this.sourceID,
    required this.title,
    this.posterURL,
    this.synopsis,
    this.year,
  });
}

class EpisodeItem {
  final String episodeID;
  final String title;
  final dynamic episodeNumber;

  EpisodeItem({
    required this.episodeID,
    required this.title,
    this.episodeNumber,
  });
}

class SubtitleTrack {
  final String url;
  final String label;
  final String languageCode;

  SubtitleTrack({
    required this.url,
    required this.label,
    required this.languageCode,
  });
}

class StreamCandidate {
  final String url;
  final String qualityLabel;
  final String mediaTypeHint;
  final Map<String, String>? headers;
  final List<SubtitleTrack> subtitles;

  StreamCandidate({
    required this.url,
    required this.qualityLabel,
    required this.mediaTypeHint,
    this.headers,
    this.subtitles = const [],
  });

  bool get isProgressiveDownload {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mkv') ||
        path.endsWith('.webm');
  }
}
