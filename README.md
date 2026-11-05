# Mehmmy – Ride Rewards

**Get a ride. Give a Mehmmy.** Mehmmy is a small loyalty app for friends who drive each other around. The rider logs every lift, the driver banks a *Mehmmy* plus the real road distance, and once a driver has enough Mehmmys they cash them in for a reward the rider promised: a coffee, a gift card, the first round.

Domain: [mehmmys.app](https://mehmmys.app) · iOS first (App Store), Android next · global, US market first.

## How it works

| | Rider (crew owner) | Driver |
|---|---|---|
| **Ride** | Request a ride from the whole crew, or log a ride: pick the driver and the route, distance comes from Apple Maps | See open requests and claim one with *I've got you* |
| **Board** | Leaderboard of drivers by Mehmmys and distance | Same board, across every crew you drive for |
| **Rewards** | Define reward tiers (cost + description) and see each driver's wallet | Redeem a tier when your balance allows; the rider gets a push |
| **Activity** | Every ride, request, claim and redemption | Same |
| **Me** | Profile, invite code, drivers, saved places (map pin or search), units, delete account | Profile, crews, units, leave crew, delete account |

- A user owns at most one crew (as the rider) and can drive in any number of crews.
- Drivers join by invite code or link: `https://mehmmys.app/join/<CODE>`.
- Rewards are promises between friends, settled outside the app. No payments, no in-app purchases.
- Distances are stored in metres and shown in miles or kilometres from the device locale (override in settings).

## Architecture

```
iOS app (SwiftUI, iOS 17+)  ──►  Firebase Auth (Apple, Google)
                            ──►  Cloud Firestore (security rules enforce roles and balances)
                            ──►  Cloud Functions (us-central1, Node 22)
                                   ├─ callables: createCrew, joinCrew, leaveCrew, removeMember,
                                   │             linkLegacyMember, computeRoute, updateProfile,
                                   │             deleteAccount, seedDemo
                                   └─ triggers: ride / request / claim / redemption bookkeeping,
                                                activity feed, push via FCM → APNs
Marketing site (mehmmys.app) ──►  Firebase Hosting
```

- Balances, ride counts and the activity feed are written **only** by Cloud Functions; clients cannot change them.
- Triggers are idempotent and retried, so a transient failure never loses or double-counts a Mehmmy.
- Routes come from the Google Routes API with a per-crew cache, falling back to a straight-line estimate.

## Repository layout

```
ios/                        SwiftUI app (XcodeGen project: ios/project.yml)
functions/                  Cloud Functions (TypeScript), tests, scripts/
web/                        marketing site (Firebase Hosting)
firestore.rules             security rules
firestore.indexes.json      indexes
legacy-pwa/                 the original web app, deployed to GitHub Pages by .github/workflows/pages.yml
docs/superpowers/           design spec and implementation plans
```

## Development

### Backend

Requires Node 22+ and a Java 21 runtime (Android Studio's bundled JBR works).

```bash
cd functions
npm install
npm test          # unit + security-rules tests in the Auth/Firestore emulators
npm run test:e2e  # end-to-end trigger tests with the Functions emulator
```

### iOS

Requires Xcode 27+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd ios
xcodegen generate
open Mehmmy.xcodeproj
```

The preview build runs on sample data. Firebase wiring needs a `GoogleService-Info.plist` from the Firebase console placed in `ios/Mehmmy/` (it is gitignored).

### Configuration and secrets

No keys or credentials are committed. Each environment supplies its own:

| What | Where it comes from |
|---|---|
| iOS Firebase config | `ios/Mehmmy/GoogleService-Info.plist`, downloaded from the Firebase console, gitignored |
| Legacy PWA config | `legacy-pwa/firebase-config.js` (copy `firebase-config.example.js`), gitignored; in CI from the `LEGACY_FIREBASE_CONFIG_JS` repository secret |
| Routes API key, demo seed secret | Cloud Functions secrets: `firebase functions:secrets:set GOOGLE_ROUTES_API_KEY` / `SEED_SECRET` |
| Local emulator secrets | `functions/.secret.local`, gitignored |
| APNs auth key | uploaded to Firebase Cloud Messaging, never stored in the repo |

## Status

- [x] Design spec and backend plan
- [x] Backend live on `mehmmy-rewards`: rules, 14 functions, push, account deletion
- [x] iOS app wired to Firebase: Sign in with Apple / Google, crews, rides, requests, rewards, push, first-run empty states
- [x] Landing, privacy, terms and support pages on https://mehmmy-rewards.web.app
- [ ] TestFlight build (internal group "Team" ready, waiting on first upload)
- [ ] Universal links and `mehmmys.app` DNS
- [ ] App Store submission
- [ ] Android

`ios/` runs against the live backend by default. Launch with `-sample` to use built-in sample data (used by UI tests and screenshots), add `-fresh` for a brand-new empty crew.
