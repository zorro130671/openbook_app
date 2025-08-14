import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserSwitcher extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const UserSwitcher({super.key, required this.onLoginSuccess});

  @override
  State<UserSwitcher> createState() => _UserSwitcherState();
}

class _UserSwitcherState extends State<UserSwitcher> {
  final _auth = FirebaseAuth.instance;

  // Simple test users
  final List<Map<String, String>> testUsers = [
    {'email': 'test1@openbook.com', 'password': '123456'},
    {'email': 'test2@openbook.com', 'password': '123456'},
    {'email': 'test3@openbook.com', 'password': '123456'},
  ];

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login(String email, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _auth.signOut(); // Ensure previous user is signed out
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      widget.onLoginSuccess(); // Notify HomeScreen of successful login
      Navigator.pop(context); // Close user switcher screen
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Switch User')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: testUsers.length,
              itemBuilder: (context, index) {
                final user = testUsers[index];
                return ListTile(
                  title: Text(user['email']!),
                  onTap: () {
                    _login(user['email']!, user['password']!);
                  },
                );
              },
            ),
      bottomNavigationBar: _errorMessage != null
          ? Container(
              color: Colors.redAccent,
              padding: const EdgeInsets.all(12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}
