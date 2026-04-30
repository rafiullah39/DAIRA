import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  bool canResendEmail = true;
  Timer? timer;

  @override
  void initState() {
    super.initState();


    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {

      timer = Timer.periodic(
        const Duration(seconds: 3),
            (_) => checkEmailVerified(),
      );
    }
  }

  Future<void> checkEmailVerified() async {

    await FirebaseAuth.instance.currentUser?.reload();

    if (mounted) {
      setState(() {
        isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      });
    }

    if (isEmailVerified) {
      timer?.cancel();
      if (mounted) {

        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();


      setState(() => canResendEmail = false);
      await Future.delayed(const Duration(seconds: 30)); // 30 second cooldown
      if (mounted) setState(() => canResendEmail = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification email resent.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_unread_rounded, size: 80, color: DairaTheme.accentOrange),
            const SizedBox(height: 24),
            const Text(
              "VERIFY YOUR EMAIL",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "We've sent a link to your email. Please click it to activate your Daira account.",
              textAlign: TextAlign.center,
              style: TextStyle(color: DairaTheme.slateGrey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: DairaTheme.accentOrange),
            const SizedBox(height: 40),


            TextButton(
              onPressed: canResendEmail ? resendVerificationEmail : null,
              child: Text(
                canResendEmail ? "RESEND LINK" : "WAIT TO RESEND...",
                style: TextStyle(
                    color: canResendEmail ? DairaTheme.accentOrange : DairaTheme.slateGrey,
                    fontWeight: FontWeight.bold
                ),
              ),
            ),


            TextButton(
              onPressed: () async {
                timer?.cancel();
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: const Text(
                  "CANCEL & USE DIFFERENT EMAIL",
                  style: TextStyle(color: Colors.redAccent, fontSize: 12)
              ),
            ),
          ],
        ),
      ),
    );
  }
}