import 'dart:async';

import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFFF8F0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.restaurant_menu, size: 90, color: Color(0xff8B5E3C)),

            SizedBox(height: 20),

            Text(
              "AI Recipe Generator",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xff8B5E3C),
              ),
            ),

            SizedBox(height: 10),

            Text(
              "Cooking with AI 🍳",
              style: TextStyle(fontSize: 17, color: Colors.black54),
            ),

            SizedBox(height: 40),

            CircularProgressIndicator(color: Color(0xff8B5E3C)),
          ],
        ),
      ),
    );
  }
}
