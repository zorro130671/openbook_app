const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.applicationDefault(), // or provide your service account
});

const db = admin.firestore();

async function fetchUsers() {
  try {
    // Fetch all users from Firestore
    const snapshot = await db.collection('users').get();

    if (snapshot.empty) {
      console.log('No users found.');
      return;
    }

    // Print user data to the terminal
    snapshot.forEach((doc) => {
      const userData = doc.data();
      console.log(`User ID: ${doc.id}`);
      console.log(`Name: ${userData.displayName}`);
      console.log(`Email: ${userData.email}`);
      console.log(`Avatar URL: ${userData.avatarUrl}`);
      console.log(`Status Message: ${userData.statusMessage}`);
      console.log(`---------------------------------------------`);
    });

  } catch (error) {
    console.error('Error fetching users:', error);
  }
}

fetchUsers().catch(console.error);
