import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aroki_flutter/state/aroki_app_state.dart';
import 'package:aroki_flutter/screens/profile_sources_screen.dart';
import 'package:aroki_flutter/theme/aroki_theme.dart';

void main() {
  testWidgets('ProfileSourcesScreen displays header and repository UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ArokiAppState(),
        child: MaterialApp(
          theme: ArokiTheme.darkTheme,
          home: const ProfileSourcesScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Profile & Sources'), findsOneWidget);
    expect(find.text('AROKI User'), findsOneWidget);
    expect(find.text('Add Verified Repository'), findsOneWidget);
  });
}
