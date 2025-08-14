const path = require("path");
const fs = require("fs");
const admin = require("firebase-admin");

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, "keys", "staging-sa.json");

if (!fs.existsSync(keyPath)) {
  console.error("Service account file not found at", keyPath);
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.firestore();

const USERS = [
  { uid: "NhY1NzNu0FgCPCvboeHSPqoy7Ng2", displayName: "Zah Martin" },   // Zah
  { uid: "wv2OJVWg8fPo1qZTN483QGqyt132", displayName: "Sumitra Nathan" }, // Sumitra
  { uid: "XenOj61VJRc7rMmrPykMNIMhr", displayName: "Liam Wong" },        // Liam
];

async function upsertUser(uid, displayName) {
  await db.collection("users").doc(uid).set({
    displayName,
    lastSeen: new Date(),
  }, { merge: true });
}

async function ensureOneToOneChat(a, b) {
  const chatId = `chat_${[a, b].sort().join("_")}`;
  const chatRef = db.collection("chats").doc(chatId);

  await chatRef.set({
    isGroup: false,
    name: null,
    participants: [a, b].sort(),
    lastMessage: "Hello — this is a seeded chat.",
    lastMessageAt: new Date()
  }, { merge: true });

  await chatRef.collection("members").doc(a).set({
    joinedAt: new Date(),
    unreadCount: 0
  }, { merge: true });

  await chatRef.collection("members").doc(b).set({
    joinedAt: new Date(),
    unreadCount: 7
  }, { merge: true });

  const msgs = [
    { senderId: a, text: "Hey there!", sentAt: Date.now() - 60000 },
    { senderId: b, text: "Hi, how’s it going?", sentAt: Date.now() - 40000 },
    { senderId: a, text: "This is a test message.", sentAt: Date.now() - 20000 }
  ];

  for (const m of msgs) {
    await chatRef.collection("messages").add({
      senderId: m.senderId,
      text: m.text,
      sentAt: new Date(m.sentAt),
      status: "sent",
      type: "text"
    });
  }

  return chatId;
}

async function ensureGroupChat() {
  const chatId = `chat_group_Zah_Sumitra_Liam`;
  const chatRef = db.collection("chats").doc(chatId);

  await chatRef.set({
    isGroup: true,
    name: "Zah, Sumitra, and Liam's Chat",
    participants: ["NhY1NzNu0FgCPCvboeHSPqoy7Ng2", "wv2OJVWg8fPo1qZTN483QGqyt132", "XenOj61VJRc7rMmrPykMNIMhr"],
    lastMessage: "Group Chat Started!",
    lastMessageAt: new Date()
  }, { merge: true });

  const msgs = [
    { senderId: "NhY1NzNu0FgCPCvboeHSPqoy7Ng2", text: "Welcome to the group chat!", sentAt: Date.now() - 60000 },
    { senderId: "wv2OJVWg8fPo1qZTN483QGqyt132", text: "Thanks for adding me!", sentAt: Date.now() - 40000 },
    { senderId: "XenOj61VJRc7rMmrPykMNIMhr", text: "Looking forward to chatting!", sentAt: Date.now() - 20000 }
  ];

  for (const m of msgs) {
    await chatRef.collection("messages").add({
      senderId: m.senderId,
      text: m.text,
      sentAt: new Date(m.sentAt),
      status: "sent",
      type: "text"
    });
  }

  return chatId;
}

(async () => {
  for (const u of USERS) {
    await upsertUser(u.uid, u.displayName);
  }

  await ensureOneToOneChat("NhY1NzNu0FgCPCvboeHSPqoy7Ng2", "wv2OJVWg8fPo1qZTN483QGqyt132"); // Zah + Sumitra
  await ensureOneToOneChat("NhY1NzNu0FgCPCvboeHSPqoy7Ng2", "XenOj61VJRc7rMmrPykMNIMhr"); // Zah + Liam
  await ensureGroupChat(); // Group chat with Zah, Sumitra, and Liam

  console.log("Seeded users, chats, and messages.");
  process.exit(0);
})().catch(err => { console.error(err); process.exit(1); });

