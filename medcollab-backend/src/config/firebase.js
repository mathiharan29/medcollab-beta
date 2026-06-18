/**
 * FIREBASE ADMIN CONFIG
 *
 * Firebase Admin SDK is the SERVER-SIDE SDK.
 * It lets us send push notifications to doctors' phones via FCM.
 *
 * How push notifications work in this app:
 * 1. Doctor opens app → Flutter registers device with FCM → gets a token
 * 2. Flutter sends that token to our backend → stored on User document
 * 3. When a message is sent, our backend calls FCM with the recipient's token
 * 4. FCM delivers the push notification to the doctor's phone
 * 5. Notification arrives even if the app is closed
 *
 * Why this matters for doctors:
 * An emergency message must reach a doctor even when the app is backgrounded.
 * Socket.io alone cannot do this. FCM can.
 */

const admin = require('firebase-admin');
const logger = require('../utils/logger');

let firebaseApp = null;

const connectFirebase = () => {
  try {
    // Firebase private key comes from env as a string with \n literals
    // We need to replace them with actual newlines
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

    if (!privateKey || !process.env.FIREBASE_PROJECT_ID) {
      logger.warn('Firebase credentials not set. Push notifications disabled.');
      return;
    }

    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey,
      }),
    });

    logger.info('Firebase Admin connected');
  } catch (error) {
    // Don't crash the server if Firebase fails — just disable notifications
    logger.error(`Firebase init failed: ${error.message}`);
  }
};

const getFirebaseAdmin = () => {
  if (!firebaseApp) {
    throw new Error('Firebase not initialized');
  }
  return admin;
};

module.exports = { connectFirebase, getFirebaseAdmin };
