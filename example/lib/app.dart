import 'package:flutter/material.dart';

import 'screens/chat_screen.dart';
import 'screens/models_screen.dart';
import 'screens/settings_screen.dart';

/// Main app widget with bottom navigation.
class LiquidAiExampleApp extends StatefulWidget {
  const LiquidAiExampleApp({super.key});

  @override
  State<LiquidAiExampleApp> createState() => _LiquidAiExampleAppState();
}

class _LiquidAiExampleAppState extends State<LiquidAiExampleApp> {
  int _currentIndex = 0;

  static const _screens = [ModelsScreen(), ChatScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid AI Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.model_training_outlined),
              selectedIcon: Icon(Icons.model_training),
              label: 'Models',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_outlined),
              selectedIcon: Icon(Icons.chat),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
