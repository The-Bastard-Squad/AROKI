import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aroki/models/connector_models.dart';
import 'package:aroki/state/aroki_app_state.dart';
import 'package:aroki/screens/player_screen.dart';
import 'package:aroki/theme/aroki_theme.dart';

void main() {
  testWidgets('PlayerScreen renders title and episode header info',
      (WidgetTester tester) async {
    final catalogItem = CatalogItem(
      sourceID: 'naruto',
      title: 'Naruto',
      posterURL: 'https://example.com/poster.jpg',
    );

    final episodeItem = EpisodeItem(
      episodeID: '1',
      title: 'Episode 1: Enter Naruto!',
      episodeNumber: 1,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ArokiAppState(),
        child: MaterialApp(
          theme: ArokiTheme.darkTheme,
          home: PlayerScreen(
            titleItem: catalogItem,
            episode: episodeItem,
            variant: 'sub',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Naruto'), findsOneWidget);
    expect(find.text('Episode 1: Enter Naruto! (SUB)'), findsOneWidget);
  });
}
