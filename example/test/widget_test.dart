import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:example/app.dart';
import 'package:example/state/download_state.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DownloadState(),
        child: const LiquidAiExampleApp(),
      ),
    );

    // Verify that the Models tab is shown
    expect(find.text('Models'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
