import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Theme and Config
import 'theme.dart';
import 'firebase_options.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_shell.dart';
import 'screens/create_challenge_page.dart';
import 'screens/challenge_detail_screen.dart';
import 'screens/ai_forge_screen.dart';
import 'screens/user_search_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/community_pulse_screen.dart';
import 'screens/email_screen.dart'; // Import your new screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ DAIRA: Firebase Linked Successfully");
  } catch (e) {
    debugPrint("❌ DAIRA: Firebase Link Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DAIRA',
      theme: DairaTheme.darkTheme,

      // --- UPDATED AUTH GATEWAY ---
      // We use home instead of initialRoute to handle the login/verify logic dynamically
      home: const AuthGateway(),

      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/verify-email': (context) => const VerifyEmailScreen(), // Ensure class name matches your email_screen.dart
        '/dashboard': (context) => const MainShell(),
        '/ai_create': (context) => const AIForgeScreen(),
        '/create_challenge': (context) => CreateChallengePage(),
        '/profile': (context) => const ProfileScreen(),
        '/search': (context) => const UserSearchScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/community_pulse': (context) => const CommunityPulseScreen(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          return MaterialPageRoute(
            builder: (context) => const ChallengeDetailScreen(),
            settings: settings,
          );
        }
        return null;
      },

      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: DairaTheme.graphite,
            body: const Center(
              child: Text("FORGE ERROR: Route not found",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}

/// This widget decides whether to show Login, Verify Email, or Dashboard
class AuthGateway extends StatelessWidget {
  const AuthGateway({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Still connecting? Show Splash
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // 2. User is logged in
        if (snapshot.hasData) {
          final user = snapshot.data!;

          // Check if email is verified
          if (user.emailVerified) {
            return const MainShell(); // Go to Dashboard
          } else {
            return const VerifyEmailScreen(); // Go to Verification Screen
          }
        }

        // 3. Not logged in
        return LoginScreen();
      },
    );
  }
}