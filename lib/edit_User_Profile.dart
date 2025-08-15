// lib/edit_user_profile.dart

import 'package:flutter/material.dart';

class EditUserProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: const Color(0xFF121212), // Dark theme for consistency
      ),
      body: Center(
        child: Text(
          'Profile Page Coming Soon...',
          style: TextStyle(fontSize: 24, color: Colors.white),
        ),
      ),
    );
  }
}
