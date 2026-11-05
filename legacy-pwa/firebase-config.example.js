// ============================================================
//  Mehmmy — Firebase config (template)
//  Copy to firebase-config.js and fill in. firebase-config.js is
//  gitignored; the Pages workflow writes it from the
//  LEGACY_FIREBASE_CONFIG_JS repository secret at deploy time.
//  Until it is filled, the app runs in local-only mode.
// ============================================================

export const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  projectId: "YOUR_PROJECT",
  storageBucket: "YOUR_PROJECT.firebasestorage.app",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID"
};

// Everyone in the friend group must use the same group id.
export const GROUP_ID = "mehmmy-crew";

// Keyphrase that unlocks add/remove of crew and places in the legacy PWA.
export const ADMIN_KEY = "YOUR_ADMIN_KEYPHRASE";
