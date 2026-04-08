import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFFFFD700); // Gold
  static const Color secondaryColor = Color(0xFFC0C0C0); // Silver
  static const Color accentColor = Color(0xFF1E88E5); // Blue
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);
  
  // Light Theme
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      error: errorColor,
      surface: Colors.white,
      onSurface: Color(0xFF212121),
    ),
    
    // AppBar Theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF212121),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF212121),
      ),
    ),
    
    // Card Theme
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
    ),
    
    // Text Theme
    textTheme: TextTheme(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF212121),
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF212121),
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF212121),
      ),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF212121),
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF212121),
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF212121),
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        color: const Color(0xFF424242),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFF424242),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        color: const Color(0xFF757575),
      ),
    ),
    
    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: const Color(0xFF212121),
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFF757575),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFF9E9E9E),
      ),
    ),
    
    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: const Color(0xFF757575),
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
      ),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );
  
  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      error: errorColor,
      surface: Color(0xFF1E1E1E),
      onSurface: Colors.white,
    ),
    
    // AppBar Theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    
    // Card Theme
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color(0xFF1E1E1E),
    ),
    
    // Text Theme
    textTheme: TextTheme(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        color: Colors.grey[300],
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: Colors.grey[300],
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        color: Colors.grey[500],
      ),
    ),
    
    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: const Color(0xFF212121),
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: Colors.grey[400],
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: Colors.grey[600],
      ),
    ),
    
    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
      ),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );
}