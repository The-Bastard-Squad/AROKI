import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aroki/models/connector_models.dart';
import 'package:aroki/state/aroki_app_state.dart';
import 'package:aroki/screens/detail_screen.dart';
import 'package:aroki/theme/aroki_theme.dart';

void main() {
  testWidgets('TitleDetailScreen displays title name and variant chips',
      (WidgetTester tester) async {
    final catalogItem = CatalogItem(
      sourceID: 'naruto',
      title: 'Naruto',
      posterURL: 'https://example.com/poster.jpg',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ArokiAppState(),
        child: MaterialApp(
          theme: ArokiTheme.darkTheme,
          home: TitleDetailScreen(item: catalogItem),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Naruto'), findsWidgets);
    expect(find.text('SUB'), findsOneWidget);
    expect(find.text('DUB'), findsOneWidget);
  });
}
