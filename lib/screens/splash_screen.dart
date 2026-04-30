import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();


    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(_pulseController);


    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    _timer = Timer(const Duration(seconds: 3), () {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            FadeTransition(
              opacity: _fadeAnimation,
              child: RotationTransition(
                turns: _rotateController,
                child: Hero(
                  tag: 'logo',
                  child: Container(
                    width: 380,
                    height: 380,
                    padding: const EdgeInsets.all(20.0),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),


            const SizedBox(height: 20),


            const Text(
              "DAIRA",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 12,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "FORGE YOUR LEGACY",
              style: TextStyle(
                color: DairaTheme.slateGrey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 40),

            // Minimalist loading indicator
            const SizedBox(
              width: 50,
              child: LinearProgressIndicator(
                color: DairaTheme.accentOrange,
                backgroundColor: Colors.white10,
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}