import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/audio_controller.dart';
import 'theme/app_theme.dart';
import 'ui/main_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await AudioController.instance.init();
  runApp(const MergeRoyalApp());
}

class MergeRoyalApp extends StatelessWidget {
  const MergeRoyalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merge Royal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppTheme.background,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.neon,
          surface: AppTheme.background,
        ),
      ),
      home: const MainMenuScreen(),
    );
  }
}
