import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aroki/state/aroki_app_state.dart';
import 'package:aroki/screens/catalog_search_screen.dart';
import 'package:aroki/theme/aroki_theme.dart';

void main() {
  testWidgets('CatalogSearchScreen renders title search bar and appbar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ArokiAppState(),
        child: MaterialApp(
          theme: ArokiTheme.darkTheme,
          home: const CatalogSearchScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('AROKI'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
