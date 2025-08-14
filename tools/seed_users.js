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
  {
    uid: "NhY1NzNu0FgCPCvboeHSPqoy7Ng2", // Zah
    displayName: "Zah Martin",
    photoUrl: null,
    phone: null,
  }
];

(async () => {
  for (const u of USERS) {
    await db.collection("users").doc(u.uid).set({
      displayName: u.displayName,
      photoUrl: u.photoUrl ?? null,
      phone: u.phone ?? null,
      lastSeen: new Date()
    }, { merge: true });
  }
  console.log(`Seeded ${USERS.length} user(s).`);
  process.exit(0);
})().catch(err => { console.error(err); process.exit(1); });
