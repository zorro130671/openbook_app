const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

// List of users with their correct email addresses (and other details)
const users = [
  { uid: '15FYEIMqKNZT88NkcLiMZekLo3r1', email: 'charlotte@test.com', displayName: 'Charlotte' },
  { uid: '2ZSLaNoeecVoMARSMFlwva40Du93', email: 'amelia@test.com', displayName: 'Amelia' },
  { uid: '2dS760YQhPb7FN5wm5YgnLuZAQl2', email: 'mia@test.com', displayName: 'Mia' },
  { uid: 'GIwUMkcwz8VyS76sKJMgs2DNj0d2', email: 'evelyn@test.com', displayName: 'Evelyn' },
  { uid: 'HAZJlW0m1Xff0k04ZzZzUuCvVQs1', email: 'elijah@test.com', displayName: 'Elijah' },
  { uid: 'HeedsfRRVGYQPbtKwy5ArYGi7KH3', email: 'james@test.com', displayName: 'James' },
  { uid: 'LR51Szgv3HfJvAvzuVTTBoJeVsO2', email: 'william@test.com', displayName: 'William' },
  { uid: 'NhY1NzNu0FgCPCvboeHSPqoy7Ng2', email: 'zah@openbook.com', displayName: 'Zah Martin' },
  { uid: 'Rj3BR3t4EKZM1almwHFBwEqW3zQ2', email: 'emma@test.com', displayName: 'Emma' },
  { uid: 'SuyHlZwdBaT9wgsDOZTt4SGqMBG3', email: 'henry@test.com', displayName: 'Henry' },
  { uid: 'Uo6Qyv8mOAOpiUcU41hcK4E8nkd2', email: 'sophia@test.com', displayName: 'Sophia' },
  { uid: 'UqIBOhdkxjbitQyyY8Mz8XS9YUl2', email: 'alexander@test.com', displayName: 'Alexander' },
  { uid: 'XenOj61VJRc7rMmrPykMNIMhr', email: 'liam@openbook.com', displayName: 'Liam Wong is on a roll again' },
  { uid: 'XenOj61VJRc7rMmrPykMNIMhrqg2', email: 'test3@openbook.com', displayName: 'Liam Wong' },
  { uid: 'iGc6p7aD5kcFpN9nbfQdVEfjaNq1', email: 'harper@test.com', displayName: 'Harper' },
  { uid: 'japeGC7JBdSKEUpf1BQ4w0KF8Rh2', email: 'isabella@test.com', displayName: 'Isabella' },
  { uid: 'lQeSNgSgkbdg0R9ndxQAfINrWl03', email: 'oliver@test.com', displayName: 'Oliver' },
  { uid: 'oa9M1IOumFVPFzx4L6GVIU5RXcC2', email: 'noah@test.com', displayName: 'Noah' },
  { uid: 'sGCqV8P8V8SqxfDaMndl4Dpcj4r2', email: 'liam@test.com', displayName: 'Liam' },
  { uid: 'tQQd4yzXJFXVlvpGBXLpPS54b893', email: 'benjamin@test.com', displayName: 'Benjamin' },
  { uid: 'uKMKQ8KqMfhUYIxleZ2V08FSeu72', email: 'olivia@test.com', displayName: 'Olivia' },
  { uid: 'wv2OJVWg8fPo1qZTN483QGqyt132', email: 'sumitra@openbook.com', displayName: 'Sumitra Nathan' },
  { uid: 'wzQuU28BrhPxJyvflzmBeB5OGNU2', email: 'lucas@test.com', displayName: 'Lucas' },
  { uid: 'yhWia6Rl7jej6Nf87Nvk5JYr3Pz2', email: 'ava@test.com', displayName: 'Ava' },
];

// List of randomized status messages
const statusMessages = [
  "Feeling amazing",
  "On vacation",
  "Working from home",
  "Busy having coffee",
  "Away for the weekend",
  "In a meeting",
  "Taking a break",
  "Out for lunch",
  "Back in 5 minutes",
  "On a call",
  "Just finished a project",
  "Reading something interesting",
  "Travelling the world 🌎",
  "Working hard!",
  "Just woke up!"
];

// List of randomized bio messages
const bios = [
  "Tech enthusiast, always learning.",
  "Explorer of ideas and technology.",
  "Digital nomad. Making the world my office.",
  "Coffee lover and code slinger.",
  "Working on building something awesome.",
  "Passionate about life and innovation.",
  "Traveling the world while coding.",
  "Love to code, love to travel.",
  "Building the future, one line of code at a time.",
  "Just another coder trying to make the world better."
];

// Function to get a random status message from the array
function getRandomStatusMessage() {
  const randomIndex = Math.floor(Math.random() * statusMessages.length);
  return statusMessages[randomIndex];
}

// Function to get a random bio from the array
function getRandomBio() {
  const randomIndex = Math.floor(Math.random() * bios.length);
  return bios[randomIndex];
}

// Function to randomize following and followers count
function getRandomCount(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// Function to update user profiles with randomized data
async function updateUserProfiles() {
  console.log('Starting the update process...');
  
  for (const user of users) {
    console.log(`Updating profile for ${user.uid}: ${user.displayName}`);

    const userRef = db.collection('users').doc(user.uid);

    try {
      await userRef.update({
        email: user.email,
        displayName: user.displayName,
        statusMessage: getRandomStatusMessage(), // Randomized status message
        followersCount: getRandomCount(50, 500), // Randomized followers count
        followingCount: getRandomCount(50, 200), // Randomized following count
        avatarUrl: null, // Optional, can be updated with real URL if needed
        bio: getRandomBio(), // Randomized bio
        messagesCount: 0,
        postsCount: 25,
        notificationsEnabled: true,
        isDeleted: false,
        chatBackground: 'default',
        muteStatus: false,
        themePreference: 'light',
        website: `https://www.${user.uid}.com`,
        socialLinks: ['https://instagram.com/', 'https://twitter.com/'], // Example
      });

      console.log(`Successfully updated profile for user: ${user.uid}`);
    } catch (error) {
      console.error(`Error updating profile for user ${user.uid}:`, error);
    }
  }

  console.log('User profile update complete!');
}

// Run the update function
updateUserProfiles().catch(console.error);
