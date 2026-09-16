import 'dart:convert';

enum DownloadKind {
  progressive,
  hls,
}

enum DownloadTaskState {
  queued,
  resolving,
  fetching,
  merging,
  publishing,
  done,
  paused,
  failed,
}

class DownloadTask {
  final int? id;
  final String connectorId;
  final String familyID;
  final String titleID;
  final String episodeID;
  final String variant;
  final String quality;
  final String url;
  final Map<String, String> headers;
  final DownloadKind kind;
  final DownloadTaskState state;
  final int bytesTransferred;
  final int? bytesTotal;
  final String? contentUri;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;

  DownloadTask({
    this.id,
    required this.connectorId,
    required this.familyID,
    required this.titleID,
    required this.episodeID,
    required this.variant,
    required this.quality,
    required this.url,
    this.headers = const {},
    required this.kind,
    this.state = DownloadTaskState.queued,
    this.bytesTransferred = 0,
    this.bytesTotal,
    this.contentUri,
    this.error,
    required this.createdAt,
    this.completedAt,
  });

  factory DownloadTask.fromMap(Map<String, Object?> map) {
    final headersJson = map['headers'] as String? ?? '{}';
    final decodedHeaders = jsonDecode(headersJson);

    return DownloadTask(
      id: map['id'] as int?,
      connectorId: map['connectorId'] as String? ?? '',
      familyID: map['familyID'] as String? ?? '',
      titleID: map['titleID'] as String? ?? '',
      episodeID: map['episodeID'] as String? ?? '',
      variant: map['variant'] as String? ?? '',
      quality: map['quality'] as String? ?? '',
      url: map['url'] as String? ?? '',
      headers: decodedHeaders is Map
          ? decodedHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      kind: _downloadKindFromName(map['kind'] as String?),
      state: _downloadStateFromName(map['state'] as String?),
      bytesTransferred: map['bytesTransferred'] as int? ?? 0,
      bytesTotal: map['bytesTotal'] as int?,
      contentUri: map['contentUri'] as String?,
      error: map['error'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int? ?? 0,
      ),
      completedAt: map['completedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'connectorId': connectorId,
      'familyID': familyID,
      'titleID': titleID,
      'episodeID': episodeID,
      'variant': variant,
      'quality': quality,
      'url': url,
      'headers': jsonEncode(headers),
      'kind': kind.name,
      'state': state.name,
      'bytesTransferred': bytesTransferred,
      'bytesTotal': bytesTotal,
      'contentUri': contentUri,
      'error': error,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }
}

DownloadKind _downloadKindFromName(String? name) {
  return DownloadKind.values.firstWhere(
    (value) => value.name == name,
    orElse: () => DownloadKind.progressive,
  );
}

DownloadTaskState _downloadStateFromName(String? name) {
  return DownloadTaskState.values.firstWhere(
    (value) => value.name == name,
    orElse: () => DownloadTaskState.queued,
  );
}
