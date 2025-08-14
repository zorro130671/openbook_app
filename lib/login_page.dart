// lib/login_page.dart
//
// Requires these deps in pubspec.yaml:
// firebase_core, firebase_auth, google_sign_in, shared_preferences, flutter_svg, google_fonts

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // --- Form + state
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwFocus = FocusNode();

  bool _busy = false;
  bool _rememberMe = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_email') ?? '';
    setState(() {
      _emailCtrl.text = saved;
      _rememberMe = saved.isNotEmpty;
    });
  }

  Future<void> _persistRememberMe(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', email);
    } else {
      await prefs.remove('saved_email');
    }
  }

  // --- Actions
  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text.trim(),
      );
      await _persistRememberMe(_emailCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Login successful')));
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${e.message ?? "Login failed"}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        GoogleAuthProvider provider = GoogleAuthProvider();
        await auth.signInWithPopup(provider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) throw Exception('Sign-in canceled.');
        final googleAuth = await googleUser.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await auth.signInWithCredential(cred);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Signed in with Google')));
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Google Sign-In failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first.')),
      );
      return;
    }
    try {
      await auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Password reset email sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to send reset email: $e')),
      );
    }
  }

  // --- UI
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Debug-only shortcut to Home
                        if (kDebugMode)
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              tooltip: 'Skip to Home',
                              icon: const Icon(
                                Icons.bolt_outlined,
                                color: Colors.white54,
                              ),
                              onPressed: _busy
                                  ? null
                                  : () {
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => const HomeScreen(),
                                        ),
                                      );
                                    },
                            ),
                          ),
                        const SizedBox(height: 8),

                        // Logo + brand
                        _AppLogo(),
                        const SizedBox(height: 12),
                        Text(
                          'OpenBook',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 30, // slightly smaller, tighter hierarchy
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF00CFFF),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          enabled: !_busy,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _pwFocus.requestFocus(),
                          decoration: _inputDecoration(
                            hint: 'Email',
                            cs: cs,
                            icon: Icons.alternate_email,
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Email is required';
                            final ok = RegExp(
                              r'^[^@]+@[^@]+\.[^@]+',
                            ).hasMatch(t);
                            if (!ok) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password
                        TextFormField(
                          controller: _pwCtrl,
                          focusNode: _pwFocus,
                          enabled: !_busy,
                          style: const TextStyle(color: Colors.white),
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _loginEmail(),
                          decoration: _inputDecoration(
                            hint: 'Password',
                            cs: cs,
                            icon: Icons.lock_outline,
                            trailing: IconButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white54,
                              ),
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Password is required';
                            if (t.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                        ),

                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(
                                      () => _rememberMe = v ?? false,
                                    ),
                            ),
                            const Text(
                              'Remember me',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _busy ? null : _resetPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _loginEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00CFFF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Log in',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 18),
                        const _OrDivider(),
                        const SizedBox(height: 18),

                        // Social
                        _SocialButton(
                          label: 'Continue with Google',
                          asset: 'assets/logos/google_logo.svg',
                          background: Colors.white,
                          foreground: Colors.black,
                          border: BorderSide(color: Colors.white24),
                          onTap: _busy ? null : _loginGoogle,
                        ),
                        const SizedBox(height: 12),
                        _SocialButton(
                          label: 'Continue with Facebook',
                          asset: 'assets/logos/facebook_logo.svg',
                          background: Colors.white,
                          foreground: Colors.black,
                          border: BorderSide(color: Colors.white24),
                          onTap: _busy
                              ? null
                              : () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Facebook login coming soon…',
                                        ),
                                      ),
                                    ),
                        ),
                        const SizedBox(height: 12),
                        _SocialButton(
                          label: 'Continue with Apple',
                          asset: 'assets/logos/apple_logo.svg',
                          background: Colors.white,
                          foreground: Colors.black,
                          border: BorderSide(color: Colors.white24),
                          onTap: _busy
                              ? null
                              : () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Apple login coming soon…',
                                        ),
                                      ),
                                    ),
                        ),

                        const SizedBox(height: 22),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  // TODO: Navigate to your sign-up screen
                                },
                          child: const Text(
                            "Don't have an account? Sign up",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Optional: light modal scrim while busy (prevents double taps)
            if (_busy)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(color: Colors.black.withOpacity(0.10)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required ColorScheme cs,
    required IconData icon,
    Widget? trailing,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Icon(icon, color: Colors.white54),
      suffixIcon: trailing,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

// =========== Small UI helpers ===========
class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/openbook_logo_icon.png', height: 96),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    final c = Colors.white.withOpacity(.18);
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: c)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: TextStyle(color: Colors.white60),
          ),
        ),
        Expanded(child: Container(height: 1, color: c)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String asset;
  final Color background;
  final Color foreground;
  final BorderSide border;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.label,
    required this.asset,
    required this.background,
    required this.foreground,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: SvgPicture.asset(asset, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 22), // visual balance
          ],
        ),
      ),
    );
  }
}
