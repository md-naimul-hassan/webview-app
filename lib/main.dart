import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/webview_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  runApp(const HostingerPanelApp());
}

const Color kBrandColor = Color(0xFF673DE6);

class HostingerPanelApp extends StatelessWidget {
  const HostingerPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hostinger Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBrandColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const WebViewScreen(),
    );
  }
}
