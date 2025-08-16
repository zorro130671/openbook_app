import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:openbook_app/new_user_home_page.dart';
import 'package:openbook_app/services/user_service.dart';

// Toggle to true to keep the bug icon & verbose logs.
const bool DEBUG_MODE = true;

class EditUserProfilePage extends StatefulWidget {
  const EditUserProfilePage({super.key});

  @override
  State<EditUserProfilePage> createState() => _EditUserProfilePageState();
}

class _EditUserProfilePageState extends State<EditUserProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  Uint8List? _profileImageBytes; // preview & upload (web/mobile-safe)
  String? _currentAvatarUrl;
  String? _selectedGender; // null = not selected in UI
  String _selectedStatus = 'online'; // online | away | text_only

  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isLoading = true;

  // ---- QUOTES LIBRARY (expanded, incl. Moody & Leave Me Alone) ----
  final Map<String, List<String>> _bioQuotes = {
    "Inspiring": [
      "Believe you can and you're halfway there.",
      "Dream big and dare to fail.",
      "Great things never come from comfort zones.",
      "Difficult roads often lead to beautiful destinations.",
      "Don’t wait for opportunity. Create it.",
      "Keep going. Everything you need will come at the right time.",
      "Act as if what you do makes a difference. It does.",
      "Small steps every day.",
      "Turn the pain into power.",
      "Your future needs you. Your past doesn’t.",
      "Start where you are. Use what you have. Do what you can.",
      "Progress over perfection."
    ],
    "Positive": [
      "Good vibes only ✨",
      "Every day is a fresh start 🌿",
      "Choose joy today 🌞",
      "Happiness looks good on you 💫",
      "Collect moments, not things.",
      "Grateful for the little things.",
      "See the good in all things.",
      "Smiles are free—share more of them.",
      "Be kind. Always.",
      "Find the magic in the mundane.",
      "Light attracts light.",
      "Do more things that make you forget to check your phone."
    ],
    "Funny": [
      "I’m not lazy, just on energy-saving mode.",
      "I followed my heart and it led me to the fridge.",
      "Running late is my cardio.",
      "Life’s short. Smile while you still have teeth.",
      "BRB: buffering…",
      "Out of office—mentally.",
      "Professional overthinker.",
      "I put the ‘elusive’ in exclusive.",
      "Introverting in progress.",
      "404: Motivation not found.",
      "Powered by snacks.",
      "My hobbies include eating and complaining I’m getting fat."
    ],
    "Romantic": [
      "You’re my favorite notification 💌",
      "You had me at hello ❤️",
      "In a sea of people, I’ll always find you.",
      "Forever sounds nice with you.",
      "Home is wherever I’m with you.",
      "I look at you and see the rest of my life.",
      "Heart eyes, always.",
      "We’re the plot twist.",
      "You + Me = Always.",
      "I like me better when I’m with you.",
      "The stars wrote our story.",
      "Still falling for you."
    ],
    "Philosophical": [
      "I think, therefore I am.",
      "What we think, we become.",
      "The unexamined life is not worth living.",
      "We suffer more in imagination than in reality.",
      "Memento mori.",
      "Happiness depends upon ourselves.",
      "Be here now.",
      "Know thyself.",
      "Less is more.",
      "The obstacle is the way.",
      "Amor fati.",
      "Change is the only constant."
    ],
    "Motivational": [
      "Discipline equals freedom.",
      "Win the morning, win the day.",
      "One more rep. One more step.",
      "Consistency compounds.",
      "Work in silence. Let success make the noise.",
      "Trust the process.",
      "Focus > Feelings.",
      "Results take time.",
      "Show up for yourself.",
      "Outwork yesterday.",
      "Energy flows where attention goes.",
      "Hustle with heart."
    ],
    "Friendship": [
      "Friends who feel like home.",
      "Chosen family > everything.",
      "We laugh till it hurts.",
      "Memories over materials.",
      "Good times + crazy friends = great stories.",
      "Different roads, same destination.",
      "Partners in crime (the legal kind).",
      "Coffee and confidants.",
      "Real ones stay.",
      "Grateful for my people.",
      "Same chaos, different day.",
      "Better together."
    ],
    "Moody": [
      "Not every day is sunshine.",
      "Silence speaks louder than words.",
      "Some days, I just exist.",
      "Don’t expect too much from me today.",
      "Mood: off.",
      "I’m recharging—please be patient.",
      "Carrying clouds inside.",
      "Quiet doesn’t mean empty.",
      "Heavy thoughts, light replies.",
      "Be gentle—stormy weather within.",
      "Taking it minute by minute.",
      "Let the noise fade."
    ],
    "Leave Me Alone": [
      "Please don’t disturb.",
      "Recovering. Check back later.",
      "Currently unavailable for emotions.",
      "Not today. Maybe tomorrow.",
      "Heart under construction.",
      "Breakup mode: activated.",
      "I need space. Respect it.",
      "Do not disturb—healing in progress.",
      "No calls, just calm.",
      "Airplane mode: life.",
      "Building boundaries.",
      "Alone, not lonely."
    ],
  };

  late final Map<String, List<String>> _shuffledQuotes;
  final Map<String, int> _quoteCursor = {};
  String _selectedQuoteCategory = "Inspiring";

  @override
  void initState() {
    super.initState();
    // prepare shuffled pools
    _shuffledQuotes = _bioQuotes.map((k, v) {
      final list = List<String>.from(v)..shuffle();
      return MapEntry(k, list);
    });
    for (final k in _bioQuotes.keys) {
      _quoteCursor[k] = 0;
    }
    _bootstrapUserDocAndLoad(); // <- ensure schema then load
  }

  Future<void> _bootstrapUserDocAndLoad() async {
    try {
      await UserService.ensureUserDocument(); // ✅ create defaults if missing
    } catch (e) {
      _log('ensureUserDocument error: $e');
    }
    await _loadUserData();
  }

  void _log(String msg) {
    if (DEBUG_MODE) debugPrint('[EditProfile] $msg');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log('No user logged in');
        throw Exception("No user logged in");
      }

      _log('Loading Firestore doc for uid=${user.uid}');
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (snap.exists) {
        final data = snap.data()!;

        // Read both your current keys and the richer schema keys safely
        _nameController.text =
            (data['name'] ?? data['displayName'] ?? '').toString();
        _emailController.text = (data['email'] ?? '').toString();
        _phoneController.text =
            (data['phone'] ?? data['phoneNumber'] ?? '').toString();
        _bioController.text =
            (data['bio'] ?? data['statusMessage'] ?? '').toString();

        _currentAvatarUrl = (data['avatarUrl'] ?? data['photoURL']) as String?;
        final g = (data['gender'] as String?);
        _selectedGender = (g == null || g.isEmpty) ? null : g;

        // Prefer explicit status; fallback to isOnline if present
        _selectedStatus = (data['status'] as String?) ??
            ((data['isOnline'] == true) ? 'online' : 'away');

        _log(
            'Loaded profile: gender=$_selectedGender status=$_selectedStatus avatarUrl=$_currentAvatarUrl');
      } else {
        _log('User doc does not exist yet; will be created on save.');
      }
    } on FirebaseException catch (e) {
      _log('Firestore load error: ${e.code} - ${e.message}');
      _showSnack('Error loading profile: ${e.code}');
    } catch (e) {
      _log('Load error: $e');
      _showSnack('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes(); // web & mobile safe
        setState(() {
          _profileImageBytes = bytes;
        });
        _log('Picked image: ${bytes.lengthInBytes} bytes');
      }
    } catch (e) {
      _log('Image pick error: $e');
      _showSnack("Unable to pick image: $e");
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text("Take Photo"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choose from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _randomizeQuote() {
    final list = _shuffledQuotes[_selectedQuoteCategory]!;
    final i = _quoteCursor[_selectedQuoteCategory]!;
    setState(() {
      _bioController.text = list[i];
      _quoteCursor[_selectedQuoteCategory] = (i + 1) % list.length;
    });
    _log(
        'Randomized quote from "$_selectedQuoteCategory": "${_bioController.text}"');
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log('Save aborted: no user');
        throw Exception("No user logged in");
      }

      String? downloadUrl;

      // ---- Storage upload (only if new image picked) ----
      if (_profileImageBytes != null) {
        // ✅ Clean path that matches your rules: avatars/{uid}/profile.jpg
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('avatars/${user.uid}/profile.jpg');

        _log(
            'Uploading avatar to ${storageRef.fullPath} (${_profileImageBytes!.lengthInBytes} bytes)');
        await storageRef.putData(
          _profileImageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        downloadUrl = await storageRef.getDownloadURL();
        _log('Got download URL');
      } else {
        _log('No new avatar selected; skipping upload.');
      }

      // ---- Firestore write via UserService (merge update) ----
      // Keep your existing keys, and also write the "richer" keys other
      // screens expect so app logic doesn't break.
      final payload = {
        // your current keys (unchanged)
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'gender': _selectedGender ?? 'other',
        'bio': _bioController.text.trim(),
        'status': _selectedStatus,
        if (downloadUrl != null) 'avatarUrl': downloadUrl,

        // compatibility / richer schema keys
        'displayName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'photoURL': downloadUrl ?? _currentAvatarUrl,
        'statusMessage': _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : 'Available',
      };

      _log('Writing (via UserService) to users/${user.uid}: $payload');

      try {
        await UserService.updateUserFields(payload); // adds updatedAt
      } on FirebaseException catch (e) {
        // Safety net: if somehow doc isn't there yet, merge-create it.
        if (e.code == 'not-found') {
          _log('Doc not found on update, falling back to set(merge:true)');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(
            {
              ...payload,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } else {
          rethrow;
        }
      }

      _showSnack('Profile saved ✅');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NewUserHomePage()),
      );
    } on FirebaseException catch (e) {
      _log('Firebase error on save: ${e.code} - ${e.message}');
      _showSnack("Firestore/Storage error: ${e.code} — ${e.message}");
    } catch (e) {
      _log('Generic save error: $e');
      _showSnack("Error saving profile: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------- DIAGNOSTICS ----------
  Future<void> _runDiagnostics() async {
    final user = FirebaseAuth.instance.currentUser;
    _log('--- Diagnostics start ---');
    _log('Signed in? ${user != null} uid=${user?.uid}');
    _log('Gender sel=$_selectedGender  Status=$_selectedStatus');
    _log(
        'Avatar bytes? ${_profileImageBytes?.lengthInBytes}  currentUrl=$_currentAvatarUrl');

    if (user == null) {
      _showSnack('Not signed in. Please log in first.');
      _log('--- Diagnostics end (no auth) ---');
      return;
    }

    // Firestore probe
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'debugPingAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      _log('Firestore write probe: OK');
    } on FirebaseException catch (e) {
      _log('Firestore write probe FAILED: ${e.code} - ${e.message}');
      _showSnack('Firestore write failed: ${e.code}');
    }

    // Storage probe
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('debug_probes/${user.uid}/ping.txt');
      final bytes = Uint8List.fromList('ping'.codeUnits);
      await ref.putData(bytes, SettableMetadata(contentType: 'text/plain'));
      _log('Storage write probe: OK at ${ref.fullPath}');
    } on FirebaseException catch (e) {
      _log('Storage write probe FAILED: ${e.code} - ${e.message}');
      _showSnack('Storage write failed: ${e.code}');
    }

    _log('--- Diagnostics end ---');
    _showSnack('Diagnostics complete (check logs).');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        centerTitle: true,
        actions: [
          if (DEBUG_MODE)
            IconButton(
              tooltip: 'Run diagnostics',
              icon: const Icon(Icons.bug_report),
              onPressed: _runDiagnostics,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Avatar + "Edit" label
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : (_currentAvatarUrl != null
                            ? NetworkImage(_currentAvatarUrl!)
                            : const AssetImage('assets/profile_placeholder.png')
                                as ImageProvider),
                    child: (_profileImageBytes == null &&
                            _currentAvatarUrl == null)
                        ? const Icon(Icons.camera_alt,
                            size: 30, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Edit",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            // Phone
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 15),

            // Email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),

            // Gender (no prefill)
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: "Gender",
                border: OutlineInputBorder(),
              ),
              hint: const Text("Select gender"),
              items: const [
                DropdownMenuItem(value: 'male', child: Text("Male")),
                DropdownMenuItem(value: 'female', child: Text("Female")),
                DropdownMenuItem(
                    value: 'other', child: Text("Prefer not to say")),
                DropdownMenuItem(
                  value: 'none_of_your_business',
                  child: Text("None of your business"),
                ),
              ],
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 15),

            // Bio
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: "Bio",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 10),

            // Bio randomizer row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedQuoteCategory,
                    decoration: const InputDecoration(
                      labelText: "Quote category",
                      border: OutlineInputBorder(),
                    ),
                    items: _bioQuotes.keys.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedQuoteCategory = value;
                          _quoteCursor[value] = 0;
                          _shuffledQuotes[value]!.shuffle();
                        });
                        _log('Quote category -> $value');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _randomizeQuote,
                  child: const Text("Randomize"),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Status (bottom)
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: "Status",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'online', child: Text("🟢 Online")),
                DropdownMenuItem(value: 'away', child: Text("🔴 Away")),
                DropdownMenuItem(
                    value: 'text_only', child: Text("🟡 Text only")),
              ],
              onChanged: (v) => setState(() => _selectedStatus = v ?? 'online'),
            ),
            const SizedBox(height: 30),

            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save & Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
