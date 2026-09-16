import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aroki/services/declarative_extraction_engine.dart';

void main() {
  group('Declarative Extraction Engine Unit Tests', () {
    final engine = DeclarativeExtractionEngine();

    test('getValueByPath extracts nested objects correctly', () {
      const json = {
        'data': [
          {
            'slug': 'naruto',
            'title': {'english': 'Naruto', 'romaji': 'Naruto'},
            'coverImage': {'extraLarge': 'https://example.com/naruto.jpg'}
          }
        ]
      };

      final items = engine.getValueByPath(json, 'data[*]');
      expect(items, isA<List>());
      expect(items.length, 1);

      final title = engine.getValueByPath(items[0], 'title.english');
      expect(title, 'Naruto');
    });

    test('resolveField respects fallbacks and transforms', () {
      const jsonItem = {
        'title': {'userPreferred': 'One Piece'},
        'url': 'stream.m3u8'
      };

      const titleField = {
        'path': 'title.english',
        'fallbacks': [
          {'path': 'title.userPreferred'}
        ]
      };

      final title = engine.resolveField(jsonItem, titleField);
      expect(title, 'One Piece');

      const urlField = {
        'path': 'url',
        'transforms': [
          {'op': 'template', 'value': 'https://cdn.example.com/{value}'}
        ]
      };

      final url = engine.resolveField(jsonItem, urlField);
      expect(url, 'https://cdn.example.com/stream.m3u8');
    });

    test('fillUrlTemplate converts variables correctly', () {
      const tpl =
          'https://anikage.cc/api/media/anime/{titleID}/episodes/{episodeID}/sources?lang={variant}';
      final res = engine.fillUrlTemplate(
          tpl, {'titleID': 'naruto', 'episodeID': '1', 'variant': 'sub'});
      expect(res,
          'https://anikage.cc/api/media/anime/naruto/episodes/1/sources?lang=sub');
    });

    test('fetchEpisodes parses a root JSON array', () async {
      final engine = DeclarativeExtractionEngine(
        client: MockClient((request) async {
          expect(request.url.toString(),
              'https://example.com/api/anime/aot/episodes');
          return http.Response(
            '[{"number":1,"title":"To You"},{"number":2,"title":"That Day"}]',
            200,
          );
        }),
      );

      final episodes = await engine.fetchEpisodes({
        'request': {
          'method': 'GET',
          'urlTemplate': 'https://example.com/api/anime/{titleID}/episodes',
        },
        'response': {'format': 'json'},
        'extract': {
          'collection': '[*]',
          'fields': {
            'episodeID': {'path': 'number'},
            'title': {'path': 'title'},
            'episodeNumber': {'path': 'number'},
          },
        },
      }, 'aot');

      expect(episodes.length, 2);
      expect(episodes.first.episodeID, '1');
      expect(episodes.first.title, 'To You');
    });

    test('fetchEpisodes aggregates bounded episode lists', () async {
      final requested = <String>[];
      final engine = DeclarativeExtractionEngine(
        client: MockClient((request) async {
          requested.add(request.url.toString());
          switch (request.url.toString()) {
            case 'https://example.com/watch':
              return http.Response(
                '<main>'
                '<a href="https://files.example.com/list/one">One</a>'
                '<a href="https://files.example.com/list/two">Two</a>'
                '<a href="https://files.example.com/list/three">Three</a>'
                '</main>',
                200,
              );
            case 'https://files.example.com/api/list/one':
              return http.Response(
                '{"files":[{"id":"ep-1","name":"Episode 1.mp4"}]}',
                200,
              );
            case 'https://files.example.com/api/list/two':
              return http.Response(
                '{"files":[{"id":"ep-2","name":"Episode 2.mp4"}]}',
                200,
              );
          }
          return http.Response('not found', 404);
        }),
      );

      final episodes = await engine.fetchEpisodes({
        'aggregation': {
          'index': {
            'request': {
              'method': 'GET',
              'urlTemplate': 'https://example.com/watch',
            },
            'response': {'format': 'html'},
            'extract': {
              'collection': {'selector': 'a[href*="files.example.com/list/"]'},
              'fields': {
                'listURL': {
                  'selector': 'a[href*="files.example.com/list/"]',
                  'part': 'attr',
                  'attr': 'href',
                  'transforms': [
                    {
                      'op': 'replaceFirst',
                      'find': 'https://files.example.com/list/',
                      'with': 'https://files.example.com/api/list/',
                    }
                  ],
                },
              },
            },
          },
          'lists': {
            'response': {'format': 'json'},
            'extract': {
              'collection': 'files[*]',
              'fields': {
                'episodeID': {'path': 'id'},
                'title': {
                  'path': 'name',
                  'transforms': [
                    {'op': 'removeSuffix', 'value': '.mp4'},
                  ],
                },
              },
            },
          },
          'limits': {'maxLists': 2},
        },
      }, 'one-pace');

      expect(episodes.map((episode) => episode.episodeID), ['ep-1', 'ep-2']);
      expect(requested,
          isNot(contains('https://files.example.com/api/list/three')));
    });
  });
}
