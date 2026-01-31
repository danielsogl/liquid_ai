import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:example/app.dart';
import 'package:example/state/chat_state.dart';
import 'package:example/state/download_state.dart';
import 'package:example/state/tools_state.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DownloadState()),
          ChangeNotifierProvider(create: (_) => ChatState()),
          ChangeNotifierProvider(create: (_) => ToolsState()),
        ],
        child: const LiquidAiExampleApp(),
      ),
    );

    // Verify that the navigation bar tabs are shown
    expect(find.text('Models'), findsWidgets);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Structured'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
