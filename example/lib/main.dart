import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/download_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => DownloadState()..initialize(),
      child: const LiquidAiExampleApp(),
    ),
  );
}
