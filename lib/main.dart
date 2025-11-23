import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme/sikawan_theme.dart';
import 'pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SiKawanApp());
}

class SiKawanApp extends StatelessWidget {
  const SiKawanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiKawan',
      debugShowCheckedModeBanner: false,
      theme: SiKawanTheme.lightTheme,
      home: const SplashPage(),
    );
  }
}
