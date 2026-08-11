import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GhostManorApp());
}

class GhostManorApp extends StatelessWidget {
  const GhostManorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '기묘한 유령 저택',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B3E96), brightness: Brightness.dark),
      ),
      home: const Scaffold(body: Center(child: Text('기묘한 유령 저택'))),
    );
  }
}
