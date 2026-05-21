import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const AppTask());
}

class AppTask extends StatelessWidget {
  const AppTask({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Task',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      localizationsDelegates: const [
        // Required for DatePicker in pt-BR
        // Add flutter_localizations to pubspec if you need full locale support
      ],
      home: const SplashScreen(),
    );
  }
}
