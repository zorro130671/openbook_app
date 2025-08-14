const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

async function updateAlexanderProfile() {
  const userRef = db.collection('users').doc('UqIBOhdkxjbitQyyY8Mz8XS9YUl2'); // Alexander's UID

  await userRef.update({
    displayName: 'Alexander',
    email: 'alexander@test.com',
    phoneNumber: '', // No phone number provided
    statusMessage: 'Away',
    isOnline: false,
    lastSeen: admin.firestore.Timestamp.fromDate(new Date('2025-08-02T21:21:01Z')),
    avatarUrl: 'assets/images/avatars/male/alexander_scott_m.png',  // Avatar path
    avatarPath: 'avatars/male/alexander_scott_m.png',  // Avatar path as requested
    readReceipts: false,
    messagesCount: 0,
    chatBackground: 'default',
    muteStatus: false,
    themePreference: 'light',
    notificationsEnabled: true,
    isVerified: false,
    blockedUsers: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2025-08-09T08:48:09Z')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2025-08-09T21:36:13Z')),
    isDeleted: false,
    bio: '', // No bio provided
    website: '', // No website provided
    socialLinks: [], // No social links provided
    followersCount: 0,
    followingCount: 0,
    postsCount: 0,
    photoURL: 'https://randomuser.me/api/portraits/men/19.jpg', // Provided photoURL
  });

  console.log('Alexander\'s profile updated!');
}

updateAlexanderProfile().catch(console.error);
