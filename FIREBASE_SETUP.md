# Setting up Firebase (shared live leaderboard)

Right now the app works **on each phone by itself** (data saved on-device). Connecting Firebase makes one **shared leaderboard** that updates live across everyone's phones: when any friend logs a ride, the driver's Mehmmys and the activity feed update for the whole crew.

You already created a Firebase account — here's the rest, ~5 minutes. No coding.

## 1. Create a project
1. Go to **https://console.firebase.google.com** → **Add project**.
2. Name it (e.g. `mehmmy`). Google Analytics is optional — you can turn it off.
3. Wait for it to finish, then **Continue**.

## 2. Add a Web app
1. On the project home, click the **Web** icon **`</>`** ("Add app").
2. Give it a nickname (e.g. `mehmmy-web`). You do **not** need Firebase Hosting here.
3. Firebase shows you a **`firebaseConfig`** object with `apiKey`, `authDomain`, `projectId`, etc. Keep this tab open — you'll copy these values in step 5.

## 3. Create the database
1. Left sidebar → **Build → Firestore Database** → **Create database**.
2. Choose a location (any nearby region).
3. Start in **Test mode** for now → **Enable**. (We'll lock it down in step 6.)

## 4. Turn on anonymous sign-in
1. Left sidebar → **Build → Authentication → Get started**.
2. **Sign-in method** tab → enable **Anonymous** → **Save**.

## 5. Paste your config into the app
Open **`firebase-config.js`** in this folder and replace the placeholders with the values from step 2:

```js
export const firebaseConfig = {
  apiKey: "AIza…",                       // from your firebaseConfig
  authDomain: "mehmmy-xxxx.firebaseapp.com",
  projectId: "mehmmy-xxxx",
  storageBucket: "mehmmy-xxxx.appspot.com",
  messagingSenderId: "1234567890",
  appId: "1:1234567890:web:abcdef"
};

export const GROUP_ID = "mehmet-crew";   // everyone in your group uses this same value
```

Give every friend the app with the **same `GROUP_ID`** — that's what puts them on one shared board. (Change `GROUP_ID` anytime to start a fresh board.)

Redeploy (re-upload the folder). The **Me** screen will show a green **"Live"** badge once it connects, and "Synced with your crew".

## 6. Lock down the rules (before sharing widely)
Test mode lets anyone read/write for 30 days. For a private friend group, go to **Firestore → Rules** and paste this, then **Publish** — it requires the anonymous sign-in from step 4 and scopes access to group documents:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /groups/{group}/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

That's enough for a trusted friend group. (For stricter per-group secrecy you'd add a membership check, but this keeps casual snoopers out and is fine to start.)

## What syncs
- **Friends** (names, avatars, Mehmmys, miles, rides) — the leaderboard.
- **Saved places** — shared route options.
- **Activity feed** — every ride logged and reward redeemed, newest first.

Your personal counters on the **Me** screen (rides *you* took, miles *you* rode) stay per-device, since they describe your own usage.

## If something's off
- **Badge stuck on "Local"** → `apiKey` still a placeholder, or the file wasn't redeployed.
- **Badge "Local" with a console error** → check Firestore is created (step 3) and Anonymous auth is on (step 4).
- **Nothing appears for friends** → make sure everyone has the **same `GROUP_ID`**.
- The app always falls back to on-device mode if the cloud is unreachable, so it never breaks.
