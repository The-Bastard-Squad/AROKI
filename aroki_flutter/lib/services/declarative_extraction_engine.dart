import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
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

    for (final part in parts) {
      if (current == null) return null;

      final listMatch = RegExp(r'^(.+)?\[(\*|\d+)\]$').firstMatch(part);
      if (listMatch != null) {
        final key = listMatch.group(1) ?? '';
        final selector = listMatch.group(2)!;
        if (key.isNotEmpty) {
          if (current is Map && current.containsKey(key)) {
            current = current[key];
          } else {
            return null;
          }
        }
        if (current is! List) return null;
        if (selector == '*') return current;
        final index = int.tryParse(selector);
        if (index == null || index < 0 || index >= current.length) return null;
        current = current[index];
        continue;
      }

      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else if (current is List && int.tryParse(part) != null) {
        final index = int.parse(part);
        if (index < 0 || index >= current.length) return null;
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  dynamic resolveField(
    dynamic item,
    Map<String, dynamic> fieldDef, {
    Uri? baseUri,
  }) {
    dynamic resolveOne(Map<String, dynamic> def) {
      if (def.containsKey('literal')) {
        return applyTransforms(def['literal'], def['transforms'],
            baseUri: baseUri);
      }

      final selector = def['selector'] as String?;
      if (selector != null) {
        final value = _resolveSelectorField(item, def);
        if (value != null) {
          return applyTransforms(value, def['transforms'], baseUri: baseUri);
        }
      }

      final path = def['path'] as String?;
      if (path != null) {
        final value = getValueByPath(item, path);
        if (value != null) {
          return applyTransforms(value, def['transforms'], baseUri: baseUri);
        }
      }

      return null;
    }

    final value = resolveOne(fieldDef);
    if (value != null) return value;

    final fallbacks = fieldDef['fallbacks'] as List<dynamic>?;
    if (fallbacks != null) {
      for (final fallback in fallbacks) {
        if (fallback is Map<String, dynamic>) {
          final fallbackValue = resolveOne(fallback);
          if (fallbackValue != null) return fallbackValue;
        }
      }
    }

    return null;
  }

  dynamic applyTransforms(
    dynamic value,
    dynamic transforms, {
    Uri? baseUri,
  }) {
    if (value == null || transforms == null || transforms is! List) {
      return value;
    }

    dynamic current = value;
    for (final transform in transforms) {
      if (transform is! Map<String, dynamic>) continue;
      final op = transform['op'] as String?;
      final text = current?.toString() ?? '';

      switch (op) {
        case 'template':
          current =
              (transform['value'] as String? ?? '').replaceAll('{value}', text);
          break;
        case 'absolutize':
          current = _absolutize(text, baseUri);
          break;
        case 'trim':
          current = text.trim();
          break;
        case 'removePrefix':
          final prefix = transform['value']?.toString() ?? '';
          current =
              text.startsWith(prefix) ? text.substring(prefix.length) : text;
          break;
        case 'removeSuffix':
          final suffix = transform['value']?.toString() ?? '';
          current = text.endsWith(suffix)
              ? text.substring(0, text.length - suffix.length)
              : text;
          break;
        case 'replaceFirst':
          current = text.replaceFirst(
            transform['find']?.toString() ?? '',
            transform['with']?.toString() ?? '',
          );
          break;
        case 'replaceAll':
          current = text.replaceAll(
            transform['find']?.toString() ?? '',
            transform['with']?.toString() ?? '',
          );
          break;
        case 'lowercased':
        case 'lowercase':
          current = text.toLowerCase();
          break;
        case 'uppercased':
        case 'uppercase':
          current = text.toUpperCase();
          break;
        case 'removeBracketedSegments':
          current = text.replaceAll(RegExp(r'\s*[\[(][^\])]*[\])]'), '').trim();
          break;
        case 'firstInteger':
          current = RegExp(r'\d+').firstMatch(text)?.group(0) ?? '';
          break;
        case 'lastPathComponent':
          current = _lastPathComponent(text);
          break;
        case 'htmlText':
          current = html_parser.parseFragment(text).text?.trim() ?? '';
          break;
      }
    }
    return current;
  }

  String fillUrlTemplate(String urlTemplate, Map<String, String> variables) {
    var result = urlTemplate;
    variables.forEach((key, value) {
      result = result.replaceAll('{$key}', Uri.encodeComponent(value));
    });
    return result;
  }

  Future<List<CatalogItem>> fetchDiscoverySection(
    Map<String, dynamic> sectionDef, {
    int page = 1,
  }) {
    return fetchCollection(
      sectionDef,
      variables: {'page': page.toString()},
      mapper: _catalogItemFromRaw,
    );
  }

  Future<List<CatalogItem>> fetchSearchResults(
    Map<String, dynamic> searchDef,
    String query, {
    int page = 1,
  }) {
    return fetchCollection(
      searchDef,
      variables: {'query': query, 'page': page.toString()},
      mapper: _catalogItemFromRaw,
    );
  }

  Future<List<T>> fetchCollection<T>(
    Map<String, dynamic> operationDef, {
    required Map<String, String> variables,
    required T? Function(
            dynamic rawItem, Map<String, dynamic> fieldsDef, Uri baseUri)
        mapper,
    String itemsKey = 'items',
  }) async {
    final requestDef = operationDef['request'] as Map<String, dynamic>?;
    final itemsDef = operationDef[itemsKey] as Map<String, dynamic>?;
    if (requestDef == null || itemsDef == null) return [];

    final responseContext =
        await _fetchOperation(requestDef, operationDef['response'], variables);
    if (responseContext == null) return [];

    final rawList =
        _extractCollection(responseContext.data, itemsDef['collection']);
    if (rawList is! List) return [];

    final fieldsDef = itemsDef['fields'] as Map<String, dynamic>? ?? {};
    return rawList
        .map((rawItem) => mapper(rawItem, fieldsDef, responseContext.baseUri))
        .whereType<T>()
        .toList();
  }

  Future<List<EpisodeItem>> fetchEpisodes(
    Map<String, dynamic> episodesDef,
    String titleID,
  ) async {
    final aggregationDef = episodesDef['aggregation'] as Map<String, dynamic>?;
    if (aggregationDef != null) {
      return _fetchAggregatedEpisodes(aggregationDef, {'titleID': titleID});
    }

    final panelsDef = episodesDef['panels'] as Map<String, dynamic>?;
    if (panelsDef != null) {
      final expanded = await _expandEpisodePanels(
          episodesDef, panelsDef, {'titleID': titleID});
      if (expanded.isNotEmpty) return expanded;
    }

    return fetchCollection(
      episodesDef,
      variables: {'titleID': titleID},
      itemsKey: 'extract',
      mapper: _episodeFromRaw,
    );
  }

  Future<List<StreamCandidate>> fetchStreams(
    Map<String, dynamic> streamsDef, {
    required String titleID,
    required String episodeID,
    required String variant,
  }) async {
    final requestDef = streamsDef['request'] as Map<String, dynamic>?;
    final extractDef = streamsDef['extract'] as Map<String, dynamic>?;
    if (requestDef == null || extractDef == null) return [];

    final responseContext =
        await _fetchOperation(requestDef, streamsDef['response'], {
      'titleID': titleID,
      'episodeID': episodeID,
      'variant': variant,
    });
    if (responseContext == null) return [];

    final playbackHeaders = _stringMap(streamsDef['playbackHeaders']);
    final subtitles = _extractSubtitles(extractDef, responseContext);
    final rawList =
        _extractCollection(responseContext.data, extractDef['collection']);
    if (rawList is! List) return [];

    final fieldsDef = extractDef['fields'] as Map<String, dynamic>? ?? {};
    return rawList
        .map((rawItem) {
          final streamUrl = resolveField(
                rawItem,
                fieldsDef['url'] as Map<String, dynamic>? ?? {},
                baseUri: responseContext.baseUri,
              )?.toString() ??
              '';
          if (streamUrl.isEmpty) return null;
          final quality = resolveField(
                rawItem,
                fieldsDef['qualityLabel'] as Map<String, dynamic>? ?? {},
                baseUri: responseContext.baseUri,
              )?.toString() ??
              'Auto';
          final hint = resolveField(
                rawItem,
                fieldsDef['mediaTypeHint'] as Map<String, dynamic>? ?? {},
                baseUri: responseContext.baseUri,
              )?.toString() ??
              'hls';
          return StreamCandidate(
            url: streamUrl,
            qualityLabel: quality,
            mediaTypeHint: hint,
            headers: playbackHeaders.isNotEmpty ? playbackHeaders : null,
            subtitles: subtitles,
          );
        })
        .whereType<StreamCandidate>()
        .toList();
  }

  Future<_ResponseContext?> _fetchOperation(
    Map<String, dynamic> requestDef,
    dynamic responseDef,
    Map<String, String> variables,
  ) async {
    final urlTemplate = requestDef['urlTemplate'] as String? ?? '';
    final url = fillUrlTemplate(urlTemplate, variables);
    final uri = Uri.parse(url);
    final headers = _stringMap(requestDef['headers']);
    final method = (requestDef['method'] as String? ?? 'GET').toUpperCase();

    http.Response response;
    if (method == 'POST') {
      response = await _httpClient.post(
        uri,
        headers: headers,
        body: _templatedMap(requestDef['formFields'], variables),
      );
    } else {
      response = await _httpClient.get(uri, headers: headers);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return _parseResponse(response.body, uri, responseDef);
  }

  _ResponseContext _parseResponse(
      String body, Uri baseUri, dynamic responseDef) {
    final format = responseDef is Map<String, dynamic>
        ? responseDef['format']?.toString()
        : null;

    switch (format) {
      case 'html':
        return _ResponseContext(html_parser.parse(body), baseUri);
      case 'json':
      case 'json-empty-array':
      case null:
        return _ResponseContext(jsonDecode(body), baseUri);
      default:
        return _ResponseContext(body, baseUri);
    }
  }

  dynamic _extractCollection(dynamic data, dynamic collectionDef) {
    if (collectionDef == null) return null;
    if (data is dom.Document || data is dom.Element) {
      final selector = collectionDef is Map
          ? collectionDef['selector']?.toString()
          : collectionDef.toString();
      if (selector == null || selector.isEmpty) return null;
      return _querySelectorAll(data, selector);
    }

    final path = collectionDef is Map
        ? collectionDef['path']?.toString() ??
            collectionDef['collection']?.toString()
        : collectionDef.toString();
    if (path == null || path.isEmpty) return null;
    return getValueByPath(data, path);
  }

  dynamic _resolveSelectorField(dynamic item, Map<String, dynamic> fieldDef) {
    final selector = fieldDef['selector']?.toString();
    if (selector == null || selector.isEmpty) return null;

    dom.Element? element;
    if (item is dom.Element) {
      element =
          _matchesSelf(item, selector) ? item : _querySelector(item, selector);
    } else if (item is dom.Document) {
      element = _querySelector(item, selector);
    }
    if (element == null) return null;

    final part = fieldDef['part']?.toString() ?? 'text';
    if (part == 'attr') {
      final attr = fieldDef['attr']?.toString();
      return attr == null ? null : element.attributes[attr];
    }
    if (part == 'html') return element.innerHtml;
    return element.text.trim();
  }

  List<dom.Element> _querySelectorAll(dynamic node, String selector) {
    final normalized = _normalizeSelector(selector);
    if (node is dom.Document) return node.querySelectorAll(normalized);
    if (node is dom.Element) return node.querySelectorAll(normalized);
    return [];
  }

  dom.Element? _querySelector(dynamic node, String selector) {
    final normalized = _normalizeSelector(selector);
    if (node is dom.Document) return node.querySelector(normalized);
    if (node is dom.Element) return node.querySelector(normalized);
    return null;
  }

  bool _matchesSelf(dom.Element element, String selector) {
    final parent = dom.Element.tag('div')..append(element.clone(true));
    return parent.querySelector(_normalizeSelector(selector)) != null;
  }

  String _normalizeSelector(String selector) {
    return selector.replaceAll(RegExp(r':containsData\([^)]+\)'), '');
  }

  CatalogItem? _catalogItemFromRaw(
    dynamic rawItem,
    Map<String, dynamic> fieldsDef,
    Uri baseUri,
  ) {
    final sourceID = resolveField(
          rawItem,
          fieldsDef['sourceID'] as Map<String, dynamic>? ?? {},
          baseUri: baseUri,
        )?.toString() ??
        '';
    final title = resolveField(
          rawItem,
          fieldsDef['title'] as Map<String, dynamic>? ?? {},
          baseUri: baseUri,
        )?.toString() ??
        '';
    final posterURL = resolveField(
      rawItem,
      fieldsDef['posterURL'] as Map<String, dynamic>? ?? {},
      baseUri: baseUri,
    )?.toString();

    if (sourceID.isEmpty || title.isEmpty) return null;
    return CatalogItem(sourceID: sourceID, title: title, posterURL: posterURL);
  }

  EpisodeItem? _episodeFromRaw(
    dynamic rawItem,
    Map<String, dynamic> fieldsDef,
    Uri baseUri,
  ) {
    final episodeID = resolveField(
          rawItem,
          fieldsDef['episodeID'] as Map<String, dynamic>? ?? {},
          baseUri: baseUri,
        )?.toString() ??
        resolveField(
          rawItem,
          fieldsDef['episodeURL'] as Map<String, dynamic>? ?? {},
          baseUri: baseUri,
        )?.toString() ??
        '';
    if (episodeID.isEmpty) return null;
    final title = resolveField(
          rawItem,
          fieldsDef['title'] as Map<String, dynamic>? ?? {},
          baseUri: baseUri,
        )?.toString() ??
        'Episode $episodeID';
    final episodeNumber = resolveField(
      rawItem,
      fieldsDef['episodeNumber'] as Map<String, dynamic>? ?? {},
      baseUri: baseUri,
    );
    return EpisodeItem(
      episodeID: episodeID,
      title: title,
      episodeNumber: episodeNumber,
    );
  }

  Future<List<EpisodeItem>> _fetchAggregatedEpisodes(
    Map<String, dynamic> aggregationDef,
    Map<String, String> variables,
  ) async {
    final indexDef = aggregationDef['index'] as Map<String, dynamic>?;
    final listsDef = aggregationDef['lists'] as Map<String, dynamic>?;
    if (indexDef == null || listsDef == null) return [];
    final limitsDef = aggregationDef['limits'] as Map<String, dynamic>? ?? {};
    final maxLists = _positiveInt(limitsDef['maxLists']);
    final maxEpisodes = _positiveInt(limitsDef['maxEpisodes']);
    final concurrency = _positiveInt(limitsDef['maxConcurrentRequests']) ??
        _positiveInt(limitsDef['concurrency']) ??
        4;

    final indexContext = await _fetchOperation(
      indexDef['request'] as Map<String, dynamic>? ?? {},
      indexDef['response'],
      variables,
    );
    if (indexContext == null) return [];

    final indexExtract = indexDef['extract'] as Map<String, dynamic>? ?? {};
    final rawLists =
        _extractCollection(indexContext.data, indexExtract['collection']);
    if (rawLists is! List) return [];

    final indexFields = indexExtract['fields'] as Map<String, dynamic>? ?? {};
    final listUrlField = indexFields['listURL'] as Map<String, dynamic>? ?? {};
    final results = <EpisodeItem>[];
    final listUrls = <String>[];

    for (final rawList in rawLists.take(maxLists ?? rawLists.length)) {
      final listUrl =
          resolveField(rawList, listUrlField, baseUri: indexContext.baseUri)
              ?.toString();
      if (listUrl == null || listUrl.isEmpty) continue;
      listUrls.add(listUrl);
    }

    for (var start = 0; start < listUrls.length; start += concurrency) {
      final end = start + concurrency > listUrls.length
          ? listUrls.length
          : start + concurrency;
      final contexts = await Future.wait(
        listUrls.sublist(start, end).map(
              (listUrl) => _fetchOperation(
                {
                  'method': 'GET',
                  'urlTemplate': listUrl,
                  'headers': listsDef['headers'],
                },
                listsDef['response'],
                variables,
              ),
            ),
      );

      for (final listContext in contexts.whereType<_ResponseContext>()) {
        final listExtract = listsDef['extract'] as Map<String, dynamic>? ?? {};
        final rawEpisodes =
            _extractCollection(listContext.data, listExtract['collection']);
        if (rawEpisodes is! List) continue;

        final fieldsDef = listExtract['fields'] as Map<String, dynamic>? ?? {};
        for (final rawEpisode in rawEpisodes) {
          final episode =
              _episodeFromRaw(rawEpisode, fieldsDef, listContext.baseUri);
          if (episode != null) results.add(episode);
          if (maxEpisodes != null && results.length >= maxEpisodes) {
            return _dedupeEpisodes(results);
          }
        }
      }
    }

    return _dedupeEpisodes(results);
  }

  Future<List<EpisodeItem>> _expandEpisodePanels(
    Map<String, dynamic> episodesDef,
    Map<String, dynamic> panelsDef,
    Map<String, String> variables,
  ) async {
    final requestDef = episodesDef['request'] as Map<String, dynamic>?;
    final extractDef = episodesDef['extract'] as Map<String, dynamic>?;
    if (requestDef == null || extractDef == null) return [];

    final indexContext =
        await _fetchOperation(requestDef, episodesDef['response'], variables);
    if (indexContext == null) return [];

    final rawPanels =
        _extractCollection(indexContext.data, extractDef['collection']);
    if (rawPanels is! List) return [];

    final listUrlDef = panelsDef['listURL'] as Map<String, dynamic>?;
    final itemsDef = panelsDef['items'] as Map<String, dynamic>?;
    if (listUrlDef == null || itemsDef == null) return [];

    final results = <EpisodeItem>[];
    final maxPanels = panelsDef['maxPanels'] is int
        ? panelsDef['maxPanels'] as int
        : rawPanels.length;
    for (final rawPanel in rawPanels.take(maxPanels)) {
      final listUrl =
          resolveField(rawPanel, listUrlDef, baseUri: indexContext.baseUri)
              ?.toString();
      if (listUrl == null || listUrl.isEmpty) continue;
      final panelContext = await _fetchOperation(
        {
          'method': 'GET',
          'urlTemplate': listUrl,
          'headers': panelsDef['headers'],
        },
        panelsDef['response'],
        variables,
      );
      if (panelContext == null) continue;
      final rawItems =
          _extractCollection(panelContext.data, itemsDef['collection']);
      if (rawItems is! List) continue;
      final fieldsDef = itemsDef['fields'] as Map<String, dynamic>? ?? {};
      for (final rawItem in rawItems) {
        final episode =
            _episodeFromRaw(rawItem, fieldsDef, panelContext.baseUri);
        if (episode != null) results.add(episode);
      }
    }
    return _dedupeEpisodes(results);
  }

  List<SubtitleTrack> _extractSubtitles(
    Map<String, dynamic> extractDef,
    _ResponseContext responseContext,
  ) {
    final subDef = extractDef['subtitles'] as Map<String, dynamic>?;
    if (subDef == null) return [];
    final rawSubs =
        _extractCollection(responseContext.data, subDef['collection']);
    if (rawSubs is! List) return [];

    final subFields = subDef['fields'] as Map<String, dynamic>? ?? {};
    return rawSubs
        .map((rawSub) {
          final url = resolveField(
                rawSub,
                subFields['url'] as Map<String, dynamic>? ?? {},
                baseUri: responseContext.baseUri,
              )?.toString() ??
              '';
          if (url.isEmpty) return null;
          final label = resolveField(
                rawSub,
                subFields['label'] as Map<String, dynamic>? ?? {},
                baseUri: responseContext.baseUri,
              )?.toString() ??
              'English';
          final languageCode = resolveField(
                rawSub,
                subFields['languageCode'] as Map<String, dynamic>? ?? {},
                baseUri: responseContext.baseUri,
              )?.toString() ??
              'en';
          return SubtitleTrack(
              url: url, label: label, languageCode: languageCode);
        })
        .whereType<SubtitleTrack>()
        .toList();
  }

  List<EpisodeItem> _dedupeEpisodes(List<EpisodeItem> episodes) {
    final seen = <String>{};
    final result = <EpisodeItem>[];
    for (final episode in episodes) {
      if (seen.add(episode.episodeID)) result.add(episode);
    }
    return result;
  }

  Map<String, String> _stringMap(dynamic source) {
    final result = <String, String>{};
    if (source is Map) {
      source.forEach((key, value) {
        result[key.toString()] = value.toString();
      });
    }
    return result;
  }

  Map<String, String> _templatedMap(
      dynamic source, Map<String, String> variables) {
    final result = <String, String>{};
    if (source is Map) {
      source.forEach((key, value) {
        result[key.toString()] = fillUrlTemplate(value.toString(), variables);
      });
    }
    return result;
  }

  int? _positiveInt(dynamic value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  String _absolutize(String value, Uri? baseUri) {
    if (value.isEmpty || baseUri == null) return value;
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    return baseUri.resolveUri(uri).toString();
  }

  String _lastPathComponent(String value) {
    final uri = Uri.tryParse(value);
    final segments =
        uri?.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments != null && segments.isNotEmpty) return segments.last;
    final parts = value.split('/').where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? value : parts.last;
  }
}

class _ResponseContext {
  final dynamic data;
  final Uri baseUri;

  _ResponseContext(this.data, this.baseUri);
}
