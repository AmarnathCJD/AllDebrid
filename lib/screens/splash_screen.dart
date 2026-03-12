import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF050505), // Ultra-dark, almost true black for OLED
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Centered Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Minimalist Typographical Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ALL',
                      style: GoogleFonts.outfit(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'DEBRID',
                      style: GoogleFonts.outfit(
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        color: AppTheme.primaryColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 800.ms, curve: Curves.easeOutCubic)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      duration: 800.ms,
                      curve: Curves.easeOutBack,
                    )
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 800.ms,
                      curve: Curves.easeOutCubic,
                    ),

                const SizedBox(height: 16),

                // Extremely subtle tagline
                Text(
                  'STREAM EVERYTHING',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.3),
                    letterSpacing: 6,
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 800.ms).slideY(
                      begin: 0.2,
                      end: 0,
                      delay: 500.ms,
                      duration: 800.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ],
            ),
          ),

          // Tiny, elegant spinner at the bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor.withValues(alpha: 0.6),
                  ),
                ),
              ).animate().fadeIn(delay: 1000.ms, duration: 800.ms),
            ),
          ),
        ],
      ),
    );
  }
}
