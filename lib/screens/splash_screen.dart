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
                    .fadeIn(duration: 1000.ms, curve: Curves.easeOutQuint)
                    .slideY(
                      begin: 0.15,
                      end: 0,
                      duration: 1000.ms,
                      curve: Curves.easeOutQuint,
                    ),

                const SizedBox(height: 12),

                // Extremely subtle tagline
                Text(
                  'STREAM EVERYTHING',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                    letterSpacing: 8,
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 800.ms).slideY(
                      begin: 0.5,
                      end: 0,
                      delay: 600.ms,
                      duration: 800.ms,
                      curve: Curves.easeOutQuint,
                    ),
              ],
            ),
          ),

          // Tiny, elegant spinner at the bottom
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor.withValues(alpha: 0.4),
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ).animate().fadeIn(delay: 1200.ms, duration: 600.ms),
            ),
          ),
        ],
      ),
    );
  }
}
