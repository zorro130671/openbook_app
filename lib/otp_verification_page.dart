import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_field/intl_phone_field.dart'; // For phone number input with country code

class OTPVerificationPage extends StatefulWidget {
  final String verificationId; // Pass verification ID from previous step

  OTPVerificationPage({required this.verificationId});

  @override
  _OTPVerificationPageState createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final _otpController = TextEditingController();
  bool _busy = false;
  String _errorMessage = '';

  // Function to verify OTP
  Future<void> _verifyOTP() async {
    setState(() {
      _busy = true;
    });

    try {
      // Create a PhoneAuthCredential with the verificationId and OTP
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      // Sign the user in with the credential
      await FirebaseAuth.instance.signInWithCredential(credential);

      // If successful, show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number verified successfully")),
      );

      // Pop the page and return to the home screen or next screen
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Verification failed';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  // Method to send OTP (using the phone number input)
  Future<void> _sendOTP() async {
    setState(() {
      _busy = true;
    });

    final String phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Phone number is required';
        _busy = false;
      });
      return;
    }

    // Send OTP
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number verified successfully")),
        );
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _errorMessage = e.message ?? 'Verification failed';
        });
        Navigator.pop(context); // Close dialog
      },
      codeSent: (String verificationId, int? resendToken) {
        // No need to set it to widget.verificationId
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP sent to phone number")),
        );

        // Use the verificationId passed as a constructor argument
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                OTPVerificationPage(verificationId: verificationId),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Verification'),
        backgroundColor: const Color(0xFF121212),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Phone Number Input Field
            IntlPhoneField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "Phone Number"),
              onChanged: (phone) {
                setState(() {
                  // Store complete phone number
                });
              },
              initialCountryCode: 'US', // Default country code
            ),
            const SizedBox(height: 20),

            // OTP Input Field
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                filled: true,
                fillColor: Color(0xFF1E1E1E),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // Error Message
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),

            // Send OTP Button
            ElevatedButton(
              onPressed: _busy ? null : _sendOTP,
              child: _busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Send OTP'),
            ),
            const SizedBox(height: 20),

            // Verify OTP Button
            ElevatedButton(
              onPressed: _busy ? null : _verifyOTP,
              child: _busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
