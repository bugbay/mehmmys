# Mehmmy – Ride Rewards

Give a friend a **Mehmmy** every time they drive you. Native iOS app (Android next) on a Firebase backend, plus a marketing site at mehmmys.app.

## Layout

```
ios/                        SwiftUI app
functions/                  Cloud Functions (TypeScript), tests, scripts/
web/                        marketing site (Firebase Hosting)
firestore.rules, firestore.indexes.json, firebase.json
legacy-pwa/                 original PWA (served from the gh-pages branch until launch)
docs/superpowers/           design spec and implementation plans
```

## Backend tests

Requires Node 22+ and a Java 21 runtime (Android Studio's bundled JBR works).

```bash
cd functions
npm install
npm test        # runs vitest inside the Auth + Firestore emulators
```
