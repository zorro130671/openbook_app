import 'models/chat_model.dart';

final List<ChatModel> mockChats = [
  ChatModel(
    id: "chat1",
    participants: [
      "NhY1NzNu0FgCPCvboeHSPqoy7Ng2",
      "wv2OJVWg8fPo1qZTN483QGqyt132",
    ],
    lastMessage: "Hey Test3, Test1 here.",
    timestamp: DateTime(2025, 8, 7, 0, 0).toIso8601String(),
    isGroupChat: false,
    groupName: null,
  ),
  ChatModel(
    id: "chat2",
    participants: ["wv2OJVWg8fPo1qZTN483QGqyt132", "XenOj61VJRc7rMmrPykMNIMhr"],
    lastMessage: "Test2 says hello!",
    timestamp: DateTime(2025, 8, 7, 0, 0).toIso8601String(),
    isGroupChat: false,
    groupName: null,
  ),
  ChatModel(
    id: "chat3",
    participants: ["NhY1NzNu0FgCPCvboeHSPqoy7Ng2", "XenOj61VJRc7rMmrPykMNIMhr"],
    lastMessage: "Test1 and Test2 catching up.",
    timestamp: DateTime(2025, 8, 7, 0, 0).toIso8601String(),
    isGroupChat: false,
    groupName: null,
  ),
  ChatModel(
    id: "chat4",
    participants: ["testUser1", "testUser2"],
    lastMessage: "This is a test message.",
    timestamp: DateTime(2025, 8, 6, 23, 58).toIso8601String(),
    isGroupChat: false,
    groupName: null,
  ),
];
