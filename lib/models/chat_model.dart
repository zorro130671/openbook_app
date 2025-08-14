class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final String timestamp;
  final bool isGroupChat;
  final String? groupName;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.timestamp,
    required this.isGroupChat,
    this.groupName,
  });
}
