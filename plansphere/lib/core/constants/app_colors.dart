import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9C95FF);
  static const Color primaryDark = Color(0xFF4A43CC);
  static const Color primaryContainer = Color(0xFFEEEDFF);

  // Secondary Colors
  static const Color secondary = Color(0xFF9D8DFF);
  static const Color secondaryLight = Color(0xFFC7BFFF);
  static const Color secondaryDark = Color(0xFF6A5ACD);
  static const Color secondaryContainer = Color(0xFFF2F0FF);

  // Accent Colors
  static const Color accent = Color(0xFFFF6584);
  static const Color accentLight = Color(0xFFFF95A8);
  static const Color accentContainer = Color(0xFFFFEDF0);

  // Status Colors
  static const Color success = Color(0xFF00C48C);
  static const Color successLight = Color(0xFFE6FBF5);
  static const Color warning = Color(0xFFFFB800);
  static const Color warningLight = Color(0xFFFFF8E6);
  static const Color error = Color(0xFFFF4D4D);
  static const Color errorLight = Color(0xFFFFEEEE);
  static const Color info = Color(0xFF0085FF);
  static const Color infoLight = Color(0xFFE5F2FF);

  // Warranty Status Colors
  static const Color warrantyActive = Color(0xFF00C48C);
  static const Color warrantyExpiringSoon = Color(0xFFFFB800);
  static const Color warrantyExpired = Color(0xFFFF4D4D);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF5F7FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F0F8);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE8E8F0);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF666680);
  static const Color lightTextHint = Color(0xFFAAAAAD);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1A1930);
  static const Color darkSurfaceVariant = Color(0xFF242340);
  static const Color darkCard = Color(0xFF1E1D35);
  static const Color darkDivider = Color(0xFF2A2940);
  static const Color darkTextPrimary = Color(0xFFEEEEFF);
  static const Color darkTextSecondary = Color(0xFFAAAAAD);
  static const Color darkTextHint = Color(0xFF666680);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9C95FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF00D4AA), Color(0xFF5FFFD9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6584), Color(0xFFFF95A8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF0F0E1A), Color(0xFF1A1930)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient purpleBlueGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF0085FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Category Colors
  static const Map<String, Color> categoryColors = {
    'Electronics': Color(0xFF6C63FF),
    'Appliances': Color(0xFF00D4AA),
    'Food & Grocery': Color(0xFFFF9F43),
    'Medical': Color(0xFFFF6584),
    'Travel': Color(0xFF0085FF),
    'Insurance': Color(0xFF2ECC71),
    'Education': Color(0xFF9B59B6),
    'Utilities': Color(0xFF1ABC9C),
    'Fuel': Color(0xFFE67E22),
    'Entertainment': Color(0xFFE91E63),
    'Clothing': Color(0xFF3498DB),
    'Home & Garden': Color(0xFF27AE60),
    'Automobile': Color(0xFF34495E),
    'Others': Color(0xFF95A5A6),
  };

  // Glassmorphism
  static Color glassLight = Colors.white.withOpacity(0.15);
  static Color glassDark = Colors.white.withOpacity(0.05);
  static Color glassBorderLight = Colors.white.withOpacity(0.3);
  static Color glassBorderDark = Colors.white.withOpacity(0.1);
}
