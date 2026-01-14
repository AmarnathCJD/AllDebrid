import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Darker premium background
      body: Stack(
        children: [
          // Background subtle gradient/glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.15),
                // Soft glow without explicit filter
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      blurRadius: 100,
                      spreadRadius: 20)
                ],
              ),
            ).animate().fadeIn(duration: 1000.ms),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.6),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.cloud_download_rounded,
                    size: 70,
                    color: Colors.white,
                  ),
                )
                    .animate()
                    .scale(
                        begin: const Offset(0.0, 0.0),
                        end: const Offset(1.0, 1.0),
                        duration: 800.ms,
                        curve: Curves.elasticOut)
                    .then()
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                        end: 1.05,
                        duration: 1500.ms,
                        curve: Curves.easeInOut), // Breathing effect

                const SizedBox(height: 40),

                // App name
                Column(
                  children: [
                    const Text(
                      'AllDebrid',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.5,
                        height: 1,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 600.ms)
                        .slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10)),
                      child: const Text(
                        'PREMIUM MANAGER',
                        style: TextStyle(
                          color: AppTheme.primaryColor, // Accent color
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ).animate().fadeIn(delay: 500.ms, duration: 600.ms),
                  ],
                ),

                const SizedBox(height: 80),

                // Sleek loading line
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms),
              ],
            ),
          ),

          // Bottom version
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                "v1.0.0",
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ).animate().fadeIn(delay: 1000.ms),
          )
        ],
      ),
    );
  }
}
