import 'package:flutter/material.dart';

class NewUserHomePage extends StatelessWidget {
  const NewUserHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Welcome to OpenBook"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "🎉 You’ve successfully completed sign-up!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "This is your new user home page.\n"
              "Here we can safely test new features\n"
              "without breaking the live app.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Later this can be updated to go to the real home page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Future home page goes here!")),
                );
              },
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
