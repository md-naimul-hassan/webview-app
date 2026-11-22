import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview/screens/webview_page.dart';

import 'screens/webview_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  runApp(const WebViewApp());
}

const Color kBrandColor = Color(0xFF673DE6);

class WebViewApp extends StatelessWidget {
  const WebViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebView App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBrandColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const WebviewPage(),
    );
  }
}
