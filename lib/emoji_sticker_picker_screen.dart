// lib/screens/emoji_sticker_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; // For emoji picker
import 'package:giphy_picker/giphy_picker.dart'; // For Giphy stickers

class EmojiStickerPickerScreen extends StatefulWidget {
  final Function(String)
      onSelected; // Callback to return selected emoji or sticker

  const EmojiStickerPickerScreen({Key? key, required this.onSelected})
      : super(key: key);

  @override
  _EmojiStickerPickerScreenState createState() =>
      _EmojiStickerPickerScreenState();
}

class _EmojiStickerPickerScreenState extends State<EmojiStickerPickerScreen> {
  late TextEditingController _controller;
  bool _isEmojiPickerVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  // Function to toggle the emoji picker visibility
  void _toggleEmojiPicker() {
    setState(() {
      _isEmojiPickerVisible = !_isEmojiPickerVisible;
    });
  }

  // Function to handle emoji selection
  void _onEmojiSelected(Emoji emoji) {
    widget.onSelected(emoji.emoji); // Return emoji to the chat screen
    Navigator.pop(context); // Close emoji picker page
  }

  // Function to handle Giphy sticker selection
  Future<void> _onStickerSelected() async {
    final result = await GiphyPicker.pickGif(
      context: context,
      apiKey: 'your-giphy-api-key', // Get your Giphy API key from giphy.com
    );

    if (result != null) {
      widget.onSelected(result
          .images.original.url); // Return the Giphy URL to the chat screen
      Navigator.pop(context); // Close sticker picker page
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Emoji or Sticker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context), // Close picker screen
          ),
        ],
      ),
      body: Column(
        children: [
          // Button for toggling emoji picker
          ElevatedButton(
            onPressed: _toggleEmojiPicker,
            child: const Text('Select Emoji'),
          ),
          // Emoji picker visibility toggle
          if (_isEmojiPickerVisible)
            EmojiPicker(
              onEmojiSelected: (emoji, category) {
                _onEmojiSelected(emoji);
              },
              config: Config(
                columns: 7,
                emojiSizeMax: 32.0,
                verticalSpacing: 0,
                horizontalSpacing: 0,
              ),
            ),
          // Button to select stickers from Giphy
          ElevatedButton(
            onPressed: _onStickerSelected,
            child: const Text('Select Sticker'),
          ),
        ],
      ),
    );
  }
}
