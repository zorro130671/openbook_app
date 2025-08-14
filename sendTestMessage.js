const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.applicationDefault()  // Uses default credentials
});

const auth = admin.auth();

// Test creating a user
async function testFirebaseAccess() {
  try {
    // Create a test user
    const userRecord = await auth.createUser({
      email: 'testuser@example.com',
      password: 'password123',
      displayName: 'Test User'
    });
    
    console.log('User created successfully:', userRecord.uid);
    
    // Test updating the user profile
    await auth.updateUser(userRecord.uid, {
      displayName: 'Updated Test User'
    });

    console.log('User profile updated successfully!');
    
  } catch (error) {
    console.error('Error accessing Firebase Authentication:', error);
  }
}

testFirebaseAccess();
