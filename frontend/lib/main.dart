import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/shell/app_shell.dart';

void main() {
  runApp(const AAMApp());
}

class AAMApp extends StatelessWidget {
  const AAMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AAM — Panel Directivo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary:   Color(0xFF084B83),
          secondary: Color(0xFF42BFDD),
          surface:   Color(0xFFF0F6F6),
        ),
        textTheme: GoogleFonts.dmSansTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF0F6F6),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
