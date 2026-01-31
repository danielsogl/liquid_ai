import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/chat_state.dart';
import 'state/download_state.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadState()..initialize()),
        ChangeNotifierProvider(create: (_) => ChatState()),
      ],
      child: const LiquidAiExampleApp(),
    ),
  );
}
