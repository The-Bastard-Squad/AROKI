import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/connector_models.dart';

class DeclarativeExtractionEngine {
  final http.Client _httpClient;

  DeclarativeExtractionEngine({http.Client? client})
      : _httpClient = client ?? http.Client();

  dynamic getValueByPath(dynamic data, String path) {
    if (path.isEmpty || data == null) return data;
    if (path == '[*]' && data is List) return data;

    final parts = path.split('.');
    dynamic current = data;

    for (var part in parts) {
      if (current == null) return null;

      if (part.endsWith('[*]')) {
        final key = part.substring(0, part.length - 3);
        if (key.isNotEmpty) {
          if (current is Map && current.containsKey(key)) {
            current = current[key];
          } else {
            return null;
          }
        }
        if (current is List) {
          return current;
        }
        return null;
      }

      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  dynamic resolveField(dynamic item, Map<String, dynamic> fieldDef) {
    if (fieldDef.containsKey('literal')) {
      return fieldDef['literal'];
    }

    final mainPath = fieldDef['path'] as String?;
    if (mainPath != null) {
      final val = getValueByPath(item, mainPath);
      if (val != null) return applyTransforms(val, fieldDef['transforms']);
    }

    final fallbacks = fieldDef['fallbacks'] as List<dynamic>?;
    if (fallbacks != null) {
      for (var fb in fallbacks) {
        if (fb is Map<String, dynamic>) {
          final fbPath = fb['path'] as String?;
          if (fbPath != null) {
            final val = getValueByPath(item, fbPath);
            if (val != null) return applyTransforms(val, fb['transforms']);
          }
        }
      }
    }

    return null;
  }

  dynamic applyTransforms(dynamic value, dynamic transforms) {
    if (value == null || transforms == null || transforms is! List) return value;

    dynamic current = value;
    for (var t in transforms) {
      if (t is Map<String, dynamic>) {
        final op = t['op'] as String?;
        if (op == 'template') {
          final templateStr = t['value'] as String? ?? '';
          current = templateStr.replaceAll('{value}', current.toString());
        }
      }
    }
    return current;
  }

  String fillUrlTemplate(String urlTemplate, Map<String, String> variables) {
    String res = urlTemplate;
    variables.forEach((key, val) {
      res = res.replaceAll('{$key}', Uri.encodeComponent(val));
    });
    return res;
  }

  Future<List<CatalogItem>> fetchDiscoverySection(
    Map<String, dynamic> sectionDef, {
    int page = 1,
  }) async {
    final requestDef = sectionDef['request'] as Map<String, dynamic>?;
    if (requestDef == null) return [];

    final urlTemplate = requestDef['urlTemplate'] as String? ?? '';
    final url = fillUrlTemplate(urlTemplate, {'page': page.toString()});

    final headers = <String, String>{};
    if (requestDef['headers'] is Map) {
      (requestDef['headers'] as Map).forEach((k, v) {
        headers[k.toString()] = v.toString();
      });
    }

    final response = await _httpClient.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) {
      return [];
    }

    final jsonBody = jsonDecode(response.body);
    final itemsDef = sectionDef['items'] as Map<String, dynamic>?;
    if (itemsDef == null) return [];

    final collectionPath = itemsDef['collection'] as String? ?? '';
    final rawList = getValueByPath(jsonBody, collectionPath);

    List<CatalogItem> items = [];
    if (rawList is List) {
      final fieldsDef = itemsDef['fields'] as Map<String, dynamic>? ?? {};
      for (var rawItem in rawList) {
        final sourceID = resolveField(rawItem, fieldsDef['sourceID'] as Map<String, dynamic>? ?? {})?.toString() ?? '';
        final title = resolveField(rawItem, fieldsDef['title'] as Map<String, dynamic>? ?? {})?.toString() ?? '';
        final posterURL = resolveField(rawItem, fieldsDef['posterURL'] as Map<String, dynamic>? ?? {})?.toString();

        if (sourceID.isNotEmpty && title.isNotEmpty) {
          items.add(CatalogItem(sourceID: sourceID, title: title, posterURL: posterURL));
        }
      }
    }
    return items;
  }

  Future<List<CatalogItem>> fetchSearchResults(
    Map<String, dynamic> searchDef,
    String query, {
    int page = 1,
  }) async {
    final requestDef = searchDef['request'] as Map<String, dynamic>?;
    if (requestDef == null) return [];

    final urlTemplate = requestDef['urlTemplate'] as String? ?? '';
    final url = fillUrlTemplate(urlTemplate, {'query': query, 'page': page.toString()});

    final headers = <String, String>{};
    if (requestDef['headers'] is Map) {
      (requestDef['headers'] as Map).forEach((k, v) {
        headers[k.toString()] = v.toString();
      });
    }

    final response = await _httpClient.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) return [];

    final jsonBody = jsonDecode(response.body);
    final itemsDef = searchDef['items'] as Map<String, dynamic>?;
    if (itemsDef == null) return [];

    final collectionPath = itemsDef['collection'] as String? ?? '';
    final rawList = getValueByPath(jsonBody, collectionPath);

    List<CatalogItem> items = [];
    if (rawList is List) {
      final fieldsDef = itemsDef['fields'] as Map<String, dynamic>? ?? {};
      for (var rawItem in rawList) {
        final sourceID = resolveField(rawItem, fieldsDef['sourceID'] as Map<String, dynamic>? ?? {})?.toString() ?? '';
        final title = resolveField(rawItem, fieldsDef['title'] as Map<String, dynamic>? ?? {})?.toString() ?? '';
        final posterURL = resolveField(rawItem, fieldsDef['posterURL'] as Map<String, dynamic>? ?? {})?.toString();

        if (sourceID.isNotEmpty && title.isNotEmpty) {
          items.add(CatalogItem(sourceID: sourceID, title: title, posterURL: posterURL));
        }
      }
    }
    return items;
  }

  Future<List<EpisodeItem>> fetchEpisodes(
    Map<String, dynamic> episodesDef,
    String titleID,
  ) async {
    final requestDef = episodesDef['request'] as Map<String, dynamic>?;
    if (requestDef == null) return [];

    final urlTemplate = requestDef['urlTemplate'] as String? ?? '';
    final url = fillUrlTemplate(urlTemplate, {'titleID': titleID});

    final headers = <String, String>{};
    if (requestDef['headers'] is Map) {
      (requestDef['headers'] as Map).forEach((k, v) {
        headers[k.toString()] = v.toString();
      });
    }

    final response = await _httpClient.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) return [];

    final jsonBody = jsonDecode(response.body);
    final extractDef = episodesDef['extract'] as Map<String, dynamic>?;
    if (extractDef == null) return [];

    final collectionPath = extractDef['collection'] as String? ?? '';
    final rawList = getValueByPath(jsonBody, collectionPath);

    List<EpisodeItem> list = [];
    if (rawList is List) {
      final fieldsDef = extractDef['fields'] as Map<String, dynamic>? ?? {};
      for (var rawItem in rawList) {
        final epID = resolveField(rawItem, fieldsDef['episodeID'] as Map<String, dynamic>? ?? {})?.toString() ?? '';
        final title = resolveField(rawItem, fieldsDef['title'] as Map<String, dynamic>? ?? {})?.toString() ?? 'Episode $epID';
        final epNum = resolveField(rawItem, fieldsDef['episodeNumber'] as Map<String, dynamic>? ?? {});

        if (epID.isNotEmpty) {
          list.add(EpisodeItem(episodeID: epID, title: title, episodeNumber: epNum));
        }
      }
    }
    return list;
  }

  Future<List<StreamCandidate>> fetchStreams(
    Map<String, dynamic> streamsDef, {
    required String titleID,
    required String episodeID,
    required String variant,
  }) async {
    final requestDef = streamsDef['request'] as Map<String, dynamic>?;
    if (requestDef == null) return [];

    final urlTemplate = requestDef['urlTemplate'] as String? ?? '';
    final url = fillUrlTemplate(urlTemplate, {
      'titleID': titleID,
      'episodeID': episodeID,
      'variant': variant,
    });

    final headers = <String, String>{};
    if (requestDef['headers'] is Map) {
      (requestDef['headers'] as Map).forEach((k, v) {
        headers[k.toString()] = v.toString();
      });
    }

    final response = await _httpClient.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) return [];

    final jsonBody = jsonDecode(response.body);
    final extractDef = streamsDef['extract'] as Map<String, dynamic>?;
    if (extractDef == null) return [];

    final collectionPath = extractDef['collection'] as String? ?? '';
    final rawList = getValueByPath(jsonBody, collectionPath);

    final playbackHeaders = <String, String>{};
    if (streamsDef['playbackHeaders'] is Map) {
      (streamsDef['playbackHeaders'] as Map).forEach((k, v) {
        playbackHeaders[k.toString()] = v.toString();
      });
    }

    List<SubtitleTrack> subtitles = [];
    final subDef = extractDef['subtitles'] as Map<String, dynamic>?;
    if (subDef != null) {
      final subCollection = subDef['collection'] as String? ?? '';
      final rawSubs = getValueByPath(jsonBody, subCollection);
      if (rawSubs is List) {
        final subFields = subDef['fields'] as Map<String, dynamic>? ?? {};
        for (var rawSub in rawSubs) {
          final subUrl = resolveField(rawSub, subFields['url'] as Map<String, dynamic>? ?? {})?.toString() ?? '';
          final subLabel = resolveField(rawSub, subFields['label'] as Map<String, dynamic>? ?? {})?.toString() ?? 'English';
          final subLang = resolveField(rawSub, subFields['languageCode'] as Map<String, dynamic>? ?? {})?.toString() ?? 'en';

          if (subUrl.isNotEmpty) {
            subtitles.add(SubtitleTrack(url: subUrl, label: subLabel, languageCode: subLang));
          }
        }
      }
    }

    List<StreamCandidate> candidates = [];
    if (rawList is List) {
      final fieldsDef = extractDef['fields'] as Map<String, dynamic>? ?? {};
      for (var rawItem in rawList) {
        final streamUrl = resolveField(rawItem, fieldsDef['url'] as Map<String, dynamic>? ?? {})?.toString() ?? '';
        final quality = resolveField(rawItem, fieldsDef['qualityLabel'] as Map<String, dynamic>? ?? {})?.toString() ?? 'Auto';
        final hint = resolveField(rawItem, fieldsDef['mediaTypeHint'] as Map<String, dynamic>? ?? {})?.toString() ?? 'hls';

        if (streamUrl.isNotEmpty) {
          candidates.add(
            StreamCandidate(
              url: streamUrl,
              qualityLabel: quality,
              mediaTypeHint: hint,
              headers: playbackHeaders.isNotEmpty ? playbackHeaders : null,
              subtitles: subtitles,
            ),
          );
        }
      }
    }
    return candidates;
  }
}
