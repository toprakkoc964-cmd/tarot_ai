import 'package:flutter/material.dart';

/// Native splash ile bootstrap/auth bekleme ekranları arasında görsel süreklilik.
class AppStartupLoadingPage extends StatelessWidget {
  const AppStartupLoadingPage({super.key});

  static const backgroundColor = Color(0xFF17081C);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Image(
                image: AssetImage('assets/Tarot_logo.png'),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Color(0xFFD4AF37),
                strokeWidth: 2.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
