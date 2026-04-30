import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

class DairaIcon extends StatelessWidget {
  final double size;
  const DairaIcon({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Helps ensure no weird background artifacts appear
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.shield, color: Colors.orange, size: size),
    );
  }
}
class DairaTheme {
  static const Color graphite = Color(0xFF1C1C1C);
  static const Color surfaceGraphite = Color(0xFF2A2A2A);
  static const Color accentOrange = Color(0xFFFF8C00);
  static const Color softOrange = Color(0xFFFFB347); // Ensure this is here
  static const Color slateGrey = Color(0xFF757575);
  static const Color lightGrey = Color(0xFFBDBDBD);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: graphite,
    colorScheme: const ColorScheme.dark(
      primary: accentOrange,
      secondary: softOrange,
      surface: graphite, // Replaced 'background' with 'surface'
      onPrimary: Colors.black,
      onSurface: Colors.white,
    ),

    // FIXED: Changed CardTheme to CardThemeData
    cardTheme: CardThemeData(
      color: surfaceGraphite,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyLarge: const TextStyle(color: lightGrey),
      bodyMedium: const TextStyle(color: slateGrey),
    ),
  );
}