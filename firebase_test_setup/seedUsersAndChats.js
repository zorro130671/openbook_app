const admin = require("firebase-admin");
const fs = require("fs");

admin.initializeApp({
  credential: admin.credential.cert(require("./serviceAccountKey.json")),
});

const db = admin.firestore();
const auth = admin.auth();

// Avatars from randomuser.me
const avatars = [
  "https://randomuser.me/api/portraits/men/1.jpg",
  "https://randomuser.me/api/portraits/women/2.jpg",
  "https://randomuser.me/api/portraits/men/3.jpg",
  "https://randomuser.me/api/portraits/women/4.jpg",
  "https://randomuser.me/api/portraits/men/5.jpg",
  "https://randomuser.me/api/portraits/women/6.jpg",
  "https://randomuser.me/api/portraits/men/7.jpg",
  "https://randomuser.me/api/portraits/women/8.jpg",
  "https://randomuser.me/api/portraits/men/9.jpg",
  "https://randomuser.me/api/portraits/women/10.jpg",
  "https://randomuser.me/api/portraits/men/11.jpg",
  "https://randomuser.me/api/portraits/women/12.jpg",
  "https://randomuser.me/api/portraits/men/13.jpg",
  "https://randomuser.me/api/portraits/women/14.jpg",
  "https://randomuser.me/api/portraits/men/15.jpg",
  "https://randomuser.me/api/portraits/women/16.jpg",
  "https://randomuser.me/api/portraits/men/17.jpg",
  "https://randomuser.me/api/portraits/women/18.jpg",
  "https://randomuser.me/api/portraits/men/19.jpg",
  "https://randomuser.me/api/portraits/women/20.jpg"
];

const firstNames = [
  "Liam", "Olivia", "Noah", "Emma", "Oliver", "Ava", "Elijah", "Sophia",
  "James", "Isabella", "William", "Mia", "Benjamin", "Charlotte", "Lucas", "Amelia",
  "Henry", "Harper", "Alexander", "Evelyn"
];

async function seed() {
  console.log("Seeding users...");

  const userRecords = [];

  for (let i = 0; i < 20; i++) {
    const email = `${firstNames[i].toLowerCase()}@test.com`;

    try {
      // Create user in Firebase Auth
      const user = await auth.createUser({
        email: email,
        password: "password123",
        displayName: firstNames[i],
        photoURL: avatars[i]
      });

      // Add to Firestore users collection
      await db.collection("users").doc(user.uid).set({
        uid: user.uid,
        displayName: firstNames[i],
        email: email,
        photoURL: avatars[i],
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      userRecords.push(user);
      console.log(`✅ Created: ${firstNames[i]} (${email})`);
    } catch (error) {
      console.error(`⚠️ Skipped ${email} — ${error.message}`);
    }
  }

  console.log("\nSeeding chats...");

  // Create some pre-made chats
  for (let i = 0; i < 5; i++) {
    const userA = userRecords[i];
    const userB = userRecords[i + 1];

    const chatRef = db.collection("chats").doc();
    await chatRef.set({
      participants: [userA.uid, userB.uid],
      chatName: `Chat between ${userA.displayName} and ${userB.displayName}`,
      lastMessage: `Hi from ${userA.displayName}!`,
      lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      unreadCounts: {
        [userA.uid]: 0,
        [userB.uid]: 1
      }
    });

    await chatRef.collection("messages").add({
      senderId: userA.uid,
      text: `Hi from ${userA.displayName}!`,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`💬 Created chat: ${userA.displayName} ↔ ${userB.displayName}`);
  }

  console.log("\n✅ All done!");
}

seed();

