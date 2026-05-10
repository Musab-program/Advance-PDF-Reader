import 'package:flutter/material.dart';

class CustomSplashScreen extends StatelessWidget {
  final String title;
  const CustomSplashScreen({super.key, this.title = 'All PDF Reader'});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1B2A), // Deep Navy background
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            // Center PDF Icon (Blue & Layered as in photo)
            Stack(
              alignment: Alignment.center,
              children: [
                // Background layers
                Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2A3A),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.blue,
                      size: 70,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(flex: 2),
            // Loading text
            const Text(
              'Loading... please wait a few seconds',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 16),
            // Navy Progress Bar (Full width moving)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  backgroundColor: Color(0xFF1E2A3A),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003366)), // Navy Bar
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
