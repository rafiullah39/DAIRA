import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final userController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  Future<void> _register() async {
    final String username = userController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields"))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {

      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );


      await userCredential.user?.sendEmailVerification();


      await userCredential.user?.updateDisplayName(username);


      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'username': username,
        'username_lowercase': username.toLowerCase(),
        'email': email,
        'streak': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/verify-email');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(e.message ?? "Registration Failed")),
        );
      }
    } catch (e) {
      debugPrint("Registration Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("JOIN DAIRA", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: DairaTheme.accentOrange)),
                const SizedBox(height: 40),
                _buildInput(userController, "Username", Icons.person_outline),
                const SizedBox(height: 15),
                _buildInput(emailController, "Email Address", Icons.email_outlined),
                const SizedBox(height: 15),


                _buildInput(
                  passwordController,
                  "Password",
                  Icons.lock_outline,
                  isPass: true,
                  isObscured: _isPasswordObscured,
                  onToggle: () {
                    setState(() {
                      _isPasswordObscured = !_isPasswordObscured;
                    });
                  },
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DairaTheme.accentOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("CREATE ACCOUNT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Already on a quest? Login", style: TextStyle(color: DairaTheme.slateGrey)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildInput(
      TextEditingController controller,
      String hint,
      IconData icon,
      {bool isPass = false, bool isObscured = false, VoidCallback? onToggle}
      ) {
    return TextField(
      controller: controller,
      obscureText: isPass ? isObscured : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: DairaTheme.slateGrey, size: 20),


        suffixIcon: isPass
            ? IconButton(
          icon: Icon(
            isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: DairaTheme.slateGrey,
            size: 20,
          ),
          onPressed: onToggle,
        )
            : null,

        hintText: hint,
        filled: true,
        fillColor: DairaTheme.surfaceGraphite.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}