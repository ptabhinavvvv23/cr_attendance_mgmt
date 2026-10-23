import 'package:flutter/material.dart';

/// Centralized typography definitions for the application.
class AppTypography {
  AppTypography._();

  static TextTheme createTextTheme({
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    return TextTheme(
      // Display / Screen Header
      headlineLarge: TextStyle(
        fontSize: 26.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primaryColor,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 22.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primaryColor,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 18.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primaryColor,
        height: 1.35,
      ),

      // Titles & Section Headers
      titleLarge: TextStyle(
        fontSize: 17.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: primaryColor,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontSize: 15.0,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: secondaryColor,
        height: 1.4,
      ),

      // Body Text
      bodyLarge: TextStyle(
        fontSize: 15.0,
        fontWeight: FontWeight.w400,
        color: primaryColor,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        color: primaryColor,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
        height: 1.4,
      ),

      // Interactive Labels & Buttons
      labelLarge: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primaryColor,
      ),
      labelMedium: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: secondaryColor,
      ),
      labelSmall: TextStyle(
        fontSize: 10.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: secondaryColor,
      ),
    );
  }
}
