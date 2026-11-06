# Mehmmy – Ride Rewards: Native App Design

**Date:** 2026-11-05
**Status:** Approved (sections 1–5 reviewed with Ozzy in conversation)
**Scope:** iOS v1 (SwiftUI) + Firebase backend + marketing web. Android follows v1 on the same backend.

## 1. Background

The current app is a single-file PWA (`index.html` + Firestore sync) built by Buğrahan for one friend group. It models one rider ("Mehmed") whose friends drive him; each ride banks the driver one *Mehmmy* plus real route miles, drivers climb a leaderboard and redeem fixed reward tiers. It uses anonymous auth, one hard-coded group, a shared admin keyphrase in source, OSRM demo + Nominatim for routing (both disallow production app use), and in-page notifications that only fire while the PWA is open.

Goal: ship the same idea as a native App Store app under Ozzy's developer account, generalised so anyone can run their own crew, with real accounts, real push, and a Firebase backend. Keep it small.

## 2. Product model

### Roles

- **Owner** (the rider): owns exactly one crew. Defines the crew's places and reward tiers, logs rides, sends ride requests, invites drivers, removes members, marks redemptions delivered.
- **Driver**: joins any number of crews by invite code. Sees the leaderboard and their own balance per crew, redeems rewards when the balance allows, claims ride requests.
- A user can be owner of one crew and driver in many. Balances are per crew per driver.
- Drivers cannot log rides. The person who pays the rewards keeps the ledger, so no dispute/approval flow is needed in v1.

### Flows

- **Onboarding:** Sign in with Apple or Google → pick display name + emoji → "Create a crew" or "Join with code". Arriving via an invite link joins directly after sign-in.
- **Invite:** owner shares `https://mehmmys.app/join/{CODE}`. Installed app opens via universal link and joins. Otherwise the web page shows the code and the App Store link; the user enters the code after install.
- **Log ride (owner):** pick driver → pick from/to places → route distance shown on a small map card → "Log ride · +1 for Leo". Driver gets a push.
- **Request ride (owner):** from/to/when → "Send to the crew". All drivers get a push. A driver taps "I've got you" → owner gets a push, request shows as claimed in the feed.
- **Redeem (driver):** wallet shows balance and tiers; "Redeem" on an unlocked tier deducts immediately and pushes the owner. Owner can mark it delivered (status only, optional).
- **Leave / delete:** driver can leave a crew (balance forfeited, confirm dialog). Any user can delete their account in Me (required by App Store 5.1.1(v)); an owner is warned their crew and all its data will be deleted.

### Screens (5 tabs, same structure as the PWA)

1. **Ride** — Request / Log toggle at top (owner only; drivers see the open requests of their crews with "I've got you").
2. **Board** — top driver card + ranked list; crew switcher when in more than one crew.
3. **Rewards** — owner: tier editor + per-driver wallet view; driver: own wallet, progress bar, Redeem buttons.
4. **Activity** — rides, requests, claims, redemptions for the current crew, newest first.
5. **Me** — profile (name, emoji, colour), crews (create / join / leave), places (owner), notification setting, distance unit (auto / mi / km), delete account, sign out.

Default reward tiers on crew creation (editable free text, no hard-coded currency):

| cost | icon | title | subtitle |
|---|---|---|---|
| 3 | ☕ | Coffee or bakery treat | Latte, pastry or cookie |
| 5 | 💳 | $15 gift card | Your pick of spot |
| 7 | 🍻 | Happy hour or $25 card | First round covered |
| 10 | 🎁 | $50 gift card | The big one |

### Explicitly out of v1

Live GPS trip tracking, background location, monthly seasons/resets, multi-owner crews, in-app purchases or any money movement, chat, dark mode, Turkish localisation (strings are localisation-ready from day one).

## 3. Data model (Firestore)

```
users/{uid}
  displayName, emoji, color, email, unit ("auto"|"mi"|"km"), fcmTokens[], ownedCrewId?, createdAt

crews/{crewId}
  name, ownerUid, inviteCode, rewardTiers[{id, cost, icon, title, subtitle}], createdAt
  members/{uid}        role ("owner"|"driver"), displayName, emoji, color, mehmmys, meters, rides, joinedAt
  places/{placeId}     name, lat, lng, createdAt
  rides/{rideId}       driverUid, fromPlaceId, fromName, toPlaceId, toName, meters, estimated (bool), ts, createdBy
  requests/{reqId}     byUid, fromName, toName, when ("now"|"morning"|"afternoon"|"tonight"), ts, claimedBy?, claimedAt?
  redemptions/{redId}  driverUid, tierId, title, cost, ts, status ("pending"|"delivered"|"rejected")
  routes/{fromId_toId} meters, estimated, computedAt            (cache, Functions only)
  activity/{actId}     type ("ride"|"request"|"claim"|"redeem"), actor fields, summary fields, ts   (Functions only)

inviteCodes/{code}     crewId                                                  (Functions only)
```

Rules of thumb:

- Distances are stored in **metres**. Display converts by locale (US → miles) or the user's override.
- `members.*` counters, `activity`, `routes` and `inviteCodes` are written **only by Cloud Functions**. Clients can never change a balance directly.
- Member profile fields (name/emoji/colour) are copies for cheap rendering; a user profile edit fans out to their memberships via a Function.

### Security rules (summary)

- `crews/{id}` and all subcollections: read only if `request.auth.uid` is in `members`.
- `crews/{id}` fields `name`, `rewardTiers`: write by owner only. `inviteCode`, `ownerUid`: never by clients.
- `places`: create/update/delete by owner only.
- `rides`: create by owner only, with `createdBy == uid`, `driverUid` a member, `meters > 0`. No update/delete from clients.
- `requests`: create by owner only; update limited to setting `claimedBy == uid` and `claimedAt` by a member once (when `claimedBy` is null).
- `redemptions`: create only by `driverUid == uid`, `status == "pending"`, and `cost <= members/{uid}.mehmmys` (rule-level check; Function re-checks).
- `members`: no client writes (join/leave/remove go through Functions).
- `users/{uid}`: read/write by owner only. Other users' profiles are not readable; members copies cover display.

### Migration of the existing PWA data

One-off admin script (`functions/scripts/migrate-legacy.ts`) that reads `groups/mehmmy-crew/{friends,places,activity}` and writes a crew owned by Buğrahan's account with members pre-populated from `friends` (balances, metres from miles, ride counts) as **unclaimed** member stubs. When a driver joins via invite the owner is prompted to link the newcomer to a stub ("Is this Leo?"), which moves the stub's counters onto the real uid. Legacy `activity` is imported as read-only history.

## 4. Backend (Cloud Functions)

Firebase Functions 2nd gen, TypeScript, Node 22, region `us-central1`. Firestore in `nam5`. Firebase project `mehmmy-rewards` (Blaze plan).

### Callables

| name | input | behaviour |
|---|---|---|
| `createCrew` | `{ name }` | Fails if `users/{uid}.ownedCrewId` set. Creates crew, unique 6-char code (A–Z 2–9, no 0/O/1/I), owner member doc, default tiers, `inviteCodes/{code}`, sets `ownedCrewId`. |
| `joinCrew` | `{ code }` | Resolves code, rejects owner joining own crew or existing member, creates driver member doc from `users/{uid}` profile. Returns `crewId`. |
| `leaveCrew` | `{ crewId }` | Driver only. Deletes member doc. |
| `removeMember` | `{ crewId, uid }` | Owner only. Deletes member doc. |
| `linkLegacyMember` | `{ crewId, stubId, uid }` | Owner only. Moves stub counters onto member `uid`, deletes stub. |
| `computeRoute` | `{ crewId, fromPlaceId, toPlaceId }` | Member only. Returns cached `routes/{from_to}` if present; else Google Routes API (Compute Routes, `DRIVE`, `TRAFFIC_UNAWARE`) → metres, cache, return. On API failure returns haversine × 1.3 with `estimated: true` (also cached for 24 h only). |
| `updateProfile` | `{ displayName, emoji, color }` | Writes `users/{uid}` and fans out to every `members/{uid}` copy. |
| `deleteAccount` | – | Deletes all memberships; if owner, deletes crew subtree and its invite code; deletes `users/{uid}`; deletes the Auth user. |
| `seedDemo` | `{ secret }` | Creates a demo owner + crew with sample data for App Review. Guarded by a secret in Functions config. |

### Firestore triggers

| trigger | effect |
|---|---|
| `onRideCreated` | Transaction: `members/{driverUid}` `mehmmys +1`, `meters +x`, `rides +1`. Writes `activity` (type `ride`). Push to driver: *"{owner} gave you a Mehmmy · {from} → {to} · {distance}"*. |
| `onRequestCreated` | Writes `activity` (type `request`). Push to every member except the owner: *"{owner} needs a ride · {from} → {to} · {when}"*. |
| `onRequestUpdated` (claimedBy set) | Writes `activity` (type `claim`). Push to owner: *"{driver}'s got you 🚗"*. |
| `onRedemptionCreated` | Transaction: if balance ≥ cost, `mehmmys −cost`, `activity` (type `redeem`), push to owner: *"{driver} redeemed {title} (−{cost})"*. Else sets `status: "rejected"`. |
| `onUserDeleted` (Auth) | Safety net: same cleanup as `deleteAccount`. |

### Push

FCM HTTP v1 via Admin SDK → APNs (auth key `89GK7BVSQQ`, team `ZS9KW29SGF`, uploaded for dev + prod). Tokens live in `users/{uid}.fcmTokens[]`; the app registers on launch and on token refresh; send errors `UNREGISTERED` / `INVALID_ARGUMENT` prune the token. Every notification carries `crewId` and a `screen` key (`ride`, `board`, `rewards`, `activity`) for routing on tap.

### Routing provider

Google Routes API from the same GCP project. Free tier verified 2026-11-05: 10,000 Compute Routes Essentials calls/month, then $5 per 1,000. The per-crew route cache makes repeated place pairs free. The provider is isolated behind `computeRoute` so it can be swapped without touching clients.

### Testing

- Firebase Emulator Suite (Auth, Firestore, Functions) for local development; no test touches the live project.
- Functions integration tests (Vitest): ride → counters → activity; redemption with insufficient balance → rejected; join with bad code → error; deleteAccount on owner removes subtree.
- Rules tests with `@firebase/rules-unit-testing`: driver cannot write counters; non-member cannot read crew; owner cannot write another crew; redemption above balance denied.

## 5. iOS app

### Foundation

Xcode 16+, Swift 5 language mode, SwiftUI, deployment target iOS 17. Bundle ID `com.ozankilic.mehmmys`, App Store Connect app `6831283898`, team `ZS9KW29SGF`. Capabilities: Sign in with Apple, Push Notifications, Associated Domains (`applinks:mehmmys.app`).

Packages (SPM): `firebase-ios-sdk` (FirebaseAuth, FirebaseFirestore, FirebaseFunctions, FirebaseMessaging), `GoogleSignIn-iOS`. MapKit + `MKLocalSearch` for place search and pins (no key, no cost). `GoogleService-Info.plist` is the one downloaded after enabling Google sign-in (contains `CLIENT_ID` / `REVERSED_CLIENT_ID`).

### Structure

```
ios/Mehmmy/
  App/            MehmmyApp, AppDelegate (push registration, notification taps), DeepLinkRouter
  Core/
    Models/       User, Crew, Member, Place, Ride, RideRequest, Redemption, ActivityItem (Codable, @DocumentID)
    Services/     AuthService, CrewRepository (snapshot listeners → @Observable state),
                  FunctionsClient, PushService, RouteService, PlaceSearch
                  (each behind a protocol; Fakes in MehmmyTests)
    DesignSystem/ Tokens (colours, spacing, radii, shadows, fonts), MehmmyButton, MehmmyCard,
                  Avatar, Chip, BottomSheet, Toast
  Features/
    Onboarding/   SignInView, ProfileSetupView, CrewChoiceView (+ ViewModels)
    Ride/         RideView (Request/Log), DriverPicker, RouteCard, RequestList
    Board/        BoardView
    Rewards/      RewardsView, TierEditor, WalletCard
    Activity/     ActivityView
    Me/           MeView, PlacesEditor (MapPinSheet, PlaceSearchSheet), CrewsSection, DeleteAccountFlow
MehmmyTests/      ViewModel tests with fakes, unit-conversion tests, invite-code parsing
MehmmyUITests/    Onboarding smoke test, log-ride smoke test (emulator-backed)
```

- One `AppState` (`@Observable`) holds the signed-in user, the list of crews, and `currentCrewId`. Tabs render from it.
- Firestore offline persistence on; writes are optimistic where the rules allow (ride create, request create, redemption create).
- Deep links: `mehmmys.app/join/{code}` → if signed in, `joinCrew`; else stash the code through onboarding.

### Design system

Port the PWA's neo-brutalist language 1:1: cream `#fff8ec`, ink `#161512`, green `#2fbf71`, coral `#ff6b4a`, yellow `#ffd23f`, sky `#7dd3fc`, muted `#9a8f7a`; 2.5 pt ink borders, hard offset shadows (2–5 pt), 13–20 pt radii; Bricolage Grotesque (OFL, bundled) for display, system font for body. Dynamic Type and VoiceOver labels from the start; colour pairs checked against WCAG AA (ink on cream/yellow/green/sky all pass; muted text only on cream/white). Light appearance only in v1 (`UIUserInterfaceStyle = Light`).

### Permissions

- Location *When In Use* — only to centre the map / pin sheet on the user. Device location is never written to Firestore. Purpose string: "Used to centre the map when you save a place."
- Notifications — requested at the first ride request / ride log, not during onboarding.

### Units and language

`Measurement<UnitLength>` + `MeasurementFormatter` with the device locale (`unit == "auto"`) or the user's override. All UI strings through `String(localized:)` with an English base; Turkish is a later `.xcstrings` addition.

## 6. Web, domain, release

### Web (`web/`, Firebase Hosting, static HTML/CSS, same brand)

- `/` marketing + App Store badge (Google Play badge added with Android)
- `/join/{code}` – client-side: shows the code, store link; universal link handles the installed case
- `/privacy`, `/terms`, `/support`
- `/.well-known/apple-app-site-association` – `applinks` for `/join/*` (served with `application/json`, no redirect). Android `assetlinks.json` added later.

### DNS / email

`mehmmys.app` at Cloudflare → A/AAAA records to Firebase Hosting with the Cloudflare proxy **off** (DNS only) so Firebase can issue the certificate. `support@mehmmys.app` via Cloudflare Email Routing → Ozzy's Gmail.

### App Store

- App record: *Mehmmy – Ride Rewards*, subtitle *Reward friends who drive you*, Lifestyle / Social Networking, free, 175 regions.
- Privacy labels: Contact Info (email), Identifiers (user ID), User Content (names, place names and coordinates the user saves) — all linked to the user, used for app functionality. No device location collected, no tracking.
- Description states plainly that rewards are promises between friends settled outside the app; no payments or IAP.
- TestFlight: internal (Ozzy + Buğrahan as App Store Connect users) → external "Crew" group via public link → submit with a demo account seeded by `seedDemo` and review notes explaining the owner/driver roles.

## 7. Repository layout

```
ios/                        SwiftUI project
functions/                  TypeScript Cloud Functions, tests, scripts/
web/                        marketing site
firestore.rules, firestore.indexes.json, firebase.json, .firebaserc
legacy-pwa/                 the current PWA (stays on GitHub Pages until launch, then retired)
docs/superpowers/specs/     this document
docs/superpowers/plans/     implementation plans
```

## 8. Phases

Each phase is its own PR with emulator-backed tests.

0. Infrastructure (done 2026-11-05: App ID, App Store Connect record, Firebase iOS app, Apple + Google providers, APNs key, Blaze) + repo restructure, emulator config, CI (GitHub Actions: functions tests, rules tests).
1. Backend: rules, callables, triggers, push, route function, tests.
2. iOS: sign-in, onboarding, create/join crew, design system.
3. iOS: places (map pin + search), route distance, log ride.
4. iOS: board, rewards (tier editor + redeem), activity, me (incl. delete account).
5. Push end to end + universal links.
6. Web + DNS + email + legal pages.
7. TestFlight → review → release. Legacy data migration script and stub-linking flow.

Android (Kotlin / Compose) starts after 7 on the unchanged backend.

## 9. Open items

- Buğrahan's email for App Store Connect (Developer role, this app only) and for the Firebase `support` address decision.
- Content Rights and Age Rating declarations in App Store Connect are entered by Ozzy (legal declarations).
- Claude GitHub App is not installed on `bugbay`; pushes from automated sessions are done from Ozzy's machine.
