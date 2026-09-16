import 'package:flutter_test/flutter_test.dart';
import 'package:aroki_flutter/services/declarative_extraction_engine.dart';

void main() {
  group('Declarative Extraction Engine Unit Tests', () {
    final engine = DeclarativeExtractionEngine();

    test('getValueByPath extracts nested objects correctly', () {
      const json = {
        'data': [
          {
            'slug': 'naruto',
            'title': {
              'english': 'Naruto',
              'romaji': 'Naruto'
            },
            'coverImage': {
              'extraLarge': 'https://example.com/naruto.jpg'
            }
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
        'title': {
          'userPreferred': 'One Piece'
        },
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
          {
            'op': 'template',
            'value': 'https://cdn.example.com/{value}'
          }
        ]
      };

      final url = engine.resolveField(jsonItem, urlField);
      expect(url, 'https://cdn.example.com/stream.m3u8');
    });

    test('fillUrlTemplate converts variables correctly', () {
      const tpl = 'https://anikage.cc/api/media/anime/{titleID}/episodes/{episodeID}/sources?lang={variant}';
      final res = engine.fillUrlTemplate(tpl, {
        'titleID': 'naruto',
        'episodeID': '1',
        'variant': 'sub'
      });
      expect(res, 'https://anikage.cc/api/media/anime/naruto/episodes/1/sources?lang=sub');
    });
  });
}
