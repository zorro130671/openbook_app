import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_user_profile.dart'; // Profile page

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;
  bool _termsAccepted = false; // Track Terms and Conditions acceptance
  bool _showVerificationMessage = false;
  String _errorMessage = '';
  bool _isSignUpComplete = false; // Track if sign-up is complete

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to handle sign-up
  Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (!_termsAccepted) {
      setState(() {
        _errorMessage = 'You must accept the Terms and Conditions';
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = ''; // Clear any previous error
    });

    try {
      // Step 1: Create user with email and password
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Step 2: Store additional user info in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      // Step 3: Send email verification
      User? user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      // Step 4: Show a success message
      setState(() {
        _showVerificationMessage = true;
      });

      // Step 5: Clear email and password fields after sign-up
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();

      // Step 6: Change the button to "Login"
      setState(() {
        _isSignUpComplete = true; // User is ready to log in after sign-up
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'An unknown error occurred';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  // Function to handle login
  Future<void> _login() async {
    setState(() {
      _busy = true;
      _errorMessage = ''; // Clear any previous error
    });

    try {
      // Step 1: Sign in with email and password
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Step 2: Check if the email is verified
      if (userCredential.user != null && userCredential.user!.emailVerified) {
        // If email is verified, navigate to the profile page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EditUserProfilePage()),
        );
      } else {
        // If email is not verified, show message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please verify your email first.')),
        );
        await FirebaseAuth.instance
            .signOut(); // Sign the user out if email isn't verified
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Login failed';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: const Color(0xFF121212),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),
            // Email field
            _buildInputField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            // Password field
            _buildInputField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock,
              obscureText: _obscurePassword,
              onSuffixPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            const SizedBox(height: 20),
            // Show Confirm Password only if not signed up yet
            if (!_isSignUpComplete)
              _buildInputField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                icon: Icons.lock,
                obscureText: _obscurePassword,
              ),
            const SizedBox(height: 20),
            // Error message
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            // Terms and Conditions checkbox
            Row(
              children: [
                Checkbox(
                  value: _termsAccepted,
                  onChanged: (value) {
                    setState(() {
                      _termsAccepted = value ?? false;
                    });
                  },
                ),
                const Text(
                  'I accept the Terms and Conditions',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Sign Up/Login button
            ElevatedButton(
              onPressed: _busy ? null : (_isSignUpComplete ? _login : _signUp),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00CFFF), // Blue color
                foregroundColor: Colors.white, // White text
                minimumSize: const Size(
                    double.infinity, 50), // Full width with some height
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Rounded corners
                ),
              ),
              child: _busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isSignUpComplete ? 'Login' : 'Sign Up'),
            ),
            const SizedBox(height: 20),
            // Show verification message if the user is waiting
            if (_showVerificationMessage)
              const Text(
                "Please check your email for the verification link.",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  // Method to build the input fields (Email, Password, Confirm Password)
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    VoidCallback? onSuffixPressed,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: onSuffixPressed != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                ),
                onPressed: onSuffixPressed,
              )
            : null,
      ),
    );
  }
}
