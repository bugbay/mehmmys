# Mehmmy Backend (Phase 0 + 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the repo and ship the complete Firebase backend (rules, callables, triggers, push, routing, account deletion, demo seed) that the iOS app will consume, fully tested against the Firebase emulators.

**Architecture:** Every callable and trigger is a thin wrapper around a plain async function in `functions/src/logic/` that takes a `Firestore` instance and explicit inputs; tests call the logic directly against the Firestore/Auth emulators. Side effects that cannot run in the emulator (FCM push, Google Routes API) sit behind small interfaces with emulator-mode implementations (push → `_pushOutbox` collection; routes → haversine fake), so tests can assert on them.

**Tech Stack:** Firebase Functions 2nd gen (`firebase-functions` ^7), `firebase-admin` ^14, TypeScript 5, Node 22, Vitest ^5, `@firebase/rules-unit-testing` ^6, `firebase-tools` ^15 (emulators: auth, firestore, functions). Java 21 is required for the emulators.

**Spec:** `docs/superpowers/specs/2026-11-05-mehmmy-native-app-design.md` (sections 3, 4, 7, 8)

## Global Constraints

- Firebase project `mehmmy-rewards`, region `us-central1`, Firestore `nam5`. Never run tests against the live project; every test command goes through `firebase emulators:exec`.
- Distances are stored in **metres** (integer). Clients never receive miles from the backend.
- `members/*` counters, `activity/*`, `routes/*`, `inviteCodes/*` are written only by Functions. Rules enforce this.
- Invite codes: 6 characters from alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, stored and compared upper-case.
- Default reward tiers on crew creation (exact copy): `3 ☕ "Coffee or bakery treat" / "Latte, pastry or cookie"`, `5 💳 "$15 gift card" / "Your pick of spot"`, `7 🍻 "Happy hour or $25 card" / "First round covered"`, `10 🎁 "$50 gift card" / "The big one"`.
- Push copy (exact): ride `"{owner} gave you a Mehmmy · {from} → {to} · {distance}"`; request `"{owner} needs a ride · {from} → {to} · {when}"`; claim `"{driver}'s got you 🚗"`; redeem `"{driver} redeemed {title} (−{cost})"`. `{distance}` is formatted by the backend as `"5.3 mi"` for US-locale users and `"8.5 km"` otherwise, from `users/{uid}.unit` (`auto` → `mi` if `users/{uid}.locale` starts with `en-US`, else `km`). Every push data payload carries `crewId` and `screen` ∈ `ride|board|rewards|activity`.
- Error codes from callables use `HttpsError` codes: `unauthenticated`, `invalid-argument`, `not-found`, `already-exists`, `failed-precondition`, `permission-denied`.
- Git: one commit per task, conventional-commit subjects, commit trailers as configured for this session.
- The legacy PWA must keep working at `https://bugbay.github.io/mehmmys/` throughout.

## Review Focus

1. **Invite code input hygiene** — a user types `ab 12 cd` or `AB12CD` with trailing newline; `joinCrew` must normalise (strip whitespace, upper-case) before lookup, and a code using `0/O/1/I` must be rejected as `not-found`, never crash. Test pinned in Task 6.
2. **Concurrent redemptions** — two `redemptions` created at once for a driver with balance 5 and cost 5 each: exactly one ends `pending` with balance 0, the other `rejected`. Test pinned in Task 8.
3. **Ride against a non-member or the owner** — rules deny the write; if a document slips in (admin, bug), `applyRideCreated` must not touch counters and must mark the ride `invalid: true`. Test pinned in Task 7.
4. **Owner deletion with active members** — `deleteAccount` for an owner must recursively delete the whole crew subtree (members, places, rides, requests, redemptions, routes, activity) and free the invite code so it can be reused; the Auth user must be gone. Test pinned in Task 10.
5. **Push to a dead token** — a user with one valid and one `UNREGISTERED` token keeps exactly the valid one after a send. Test pinned in Task 5 (`FcmPushSender` prune logic with a stubbed `messaging.sendEachForMulticast`).

---

## File Structure

```
.github/workflows/functions-ci.yml      emulator-backed test run on every PR
.gitignore
.firebaserc                             { "projects": { "default": "mehmmy-rewards" } }
firebase.json                           hosting (web/), functions, firestore, emulators config
firestore.rules
firestore.indexes.json
legacy-pwa/                             the old PWA files (moved from root)
web/index.html                          placeholder until the web plan
functions/
  package.json, tsconfig.json, vitest.config.ts, .eslintrc.cjs
  src/index.ts                          exports every callable/trigger (wrappers only)
  src/types.ts                          Firestore document types
  src/lib/firestore.ts                  path helpers: crewRef(db, id), memberRef(db, crewId, uid), …
  src/lib/inviteCode.ts                 generateInviteCode(), normaliseInviteCode(), isValidInviteCode()
  src/lib/distance.ts                   haversineMeters(), estimateRoadMeters(), formatDistance()
  src/lib/defaultTiers.ts               DEFAULT_TIERS
  src/lib/errors.ts                     fail(code, message) → HttpsError
  src/lib/push.ts                       PushSender interface, FcmPushSender, OutboxPushSender, getPushSender()
  src/lib/routes.ts                     RouteProvider interface, GoogleRoutesProvider, HaversineRouteProvider, getRouteProvider()
  src/logic/crews.ts                    createCrew, joinCrew, leaveCrew, removeMember, linkLegacyMember
  src/logic/profile.ts                  updateProfile
  src/logic/rides.ts                    applyRideCreated
  src/logic/requests.ts                 applyRequestCreated, applyRequestClaimed
  src/logic/redemptions.ts              applyRedemptionCreated
  src/logic/routing.ts                  computeRoute
  src/logic/account.ts                  deleteAccount, cleanupUser
  src/logic/demo.ts                     seedDemo
  src/callables.ts                      onCall wrappers
  src/triggers.ts                       onDocumentCreated/Updated + auth.user().onDelete wrappers
  scripts/migrate-legacy.ts             one-off: groups/mehmmy-crew → crew with stubs
  test/setup.ts                         emulator env, admin app, clearFirestore()
  test/factories.ts                     makeUser(), makeCrew(), makeMember(), makePlace()
  test/*.test.ts                        one file per logic module + rules.test.ts
```

Emulator ports: auth 9099, firestore 8080, functions 5001, UI off. `functions/package.json` scripts: `build`, `test` (= `firebase emulators:exec --only auth,firestore --project mehmmy-rewards "vitest run"`), `test:watch`, `lint`, `deploy` (= `firebase deploy --only functions,firestore`).

---

### Task 1: Keep the PWA alive on `gh-pages`, restructure `main`

**Files:**
- Create: `legacy-pwa/` (moved: `index.html`, `firebase-config.js`, `firebase-sync.js`, `manifest.webmanifest`, `service-worker.js`, `icons/`, `FIREBASE_SETUP.md`)
- Create: `.gitignore`, `.firebaserc`, `firebase.json`, `firestore.indexes.json`, `web/index.html`
- Modify: `README.md`

**Interfaces:**
- Produces: `firebase.json` with `functions.source = "functions"`, `firestore.rules = "firestore.rules"`, `hosting.public = "web"`, emulators `{ auth: 9099, firestore: 8080, functions: 5001, ui: { enabled: false } }`.

- [ ] **Step 1: Create the `gh-pages` branch from the current root files and switch GitHub Pages to it**

```bash
git checkout -b gh-pages main && git push -u origin gh-pages && git checkout main
gh api -X PUT repos/bugbay/mehmmys/pages -f source[branch]=gh-pages -f source[path]=/
```
Expected: `gh api repos/bugbay/mehmmys/pages --jq .source.branch` prints `gh-pages`. (This is a repo settings change; Ozzy runs/approves it. If the API call is refused, change *Settings → Pages → Branch* to `gh-pages` in the GitHub UI.)

- [ ] **Step 2: Verify the PWA still serves**

Run: `curl -sI https://bugbay.github.io/mehmmys/ | head -1`
Expected: `HTTP/2 200` (allow a minute for Pages to rebuild).

- [ ] **Step 3: Move the PWA into `legacy-pwa/` and add the Firebase project files**

`git mv` the seven root items into `legacy-pwa/`. Write `.gitignore` (`node_modules/`, `lib/`, `*.log`, `.DS_Store`, `firebase-debug.log`, `ui-debug.log`, `.firebase/`, `functions/.env*`), `.firebaserc`, `firebase.json` per Interfaces, `firestore.indexes.json` (`{ "indexes": [], "fieldOverrides": [] }`), `web/index.html` (one line: "Mehmmy – coming soon"). Replace `README.md` with the repo layout from spec §7 plus "how to run tests".

- [ ] **Step 4: Verify the layout**

Run: `ls legacy-pwa web && test -f firebase.json && echo OK`
Expected: the seven items under `legacy-pwa/`, `index.html` under `web/`, `OK`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: move legacy PWA to legacy-pwa/, add Firebase project skeleton"
```

---

### Task 2: Functions scaffold and emulator test harness

**Files:**
- Create: `functions/package.json`, `functions/tsconfig.json`, `functions/vitest.config.ts`, `functions/.eslintrc.cjs`, `functions/src/index.ts`, `functions/test/setup.ts`, `functions/test/factories.ts`, `functions/test/smoke.test.ts`, `firestore.rules` (temporary deny-all)

**Interfaces:**
- Produces: `test/setup.ts` exports `db: Firestore` (admin, pointed at the emulator), `auth: Auth`, `clearFirestore(): Promise<void>` (HTTP DELETE on the emulator's `/emulator/v1/projects/mehmmy-rewards/documents`), and `beforeEach(clearFirestore)` is wired in `vitest.config.ts` `setupFiles`.
- Produces: `test/factories.ts` exports `makeUser(db, overrides?): Promise<{uid: string}>` (writes `users/{uid}` with `displayName: "Test", emoji: "🐢", color: "#FDBA74", unit: "auto", locale: "en-US", fcmTokens: []`), `makeCrew(db, ownerUid, overrides?): Promise<{crewId: string, inviteCode: string}>` (writes crew + owner member + inviteCodes doc + DEFAULT_TIERS), `makeMember(db, crewId, uid, overrides?)`, `makePlace(db, crewId, overrides?): Promise<{placeId: string}>`.

- [ ] **Step 1: Write `functions/package.json`**

`"engines": { "node": "22" }`, `"type": "module"`, `"main": "lib/index.js"`. Dependencies: `firebase-admin ^14`, `firebase-functions ^7`. Dev: `typescript ^5`, `vitest ^5`, `@firebase/rules-unit-testing ^6`, `firebase-tools ^15`, `eslint` + `@typescript-eslint/*`, `tsx`. Scripts as listed under File Structure.

- [ ] **Step 2: Write `tsconfig.json`, `vitest.config.ts`, `.eslintrc.cjs`, `src/index.ts`**

`tsconfig`: `module: NodeNext`, `target: ES2022`, `outDir: lib`, `strict: true`, `include: ["src"]`. `vitest.config.ts`: `test.setupFiles: ["./test/setup.ts"]`, `test.testTimeout: 20000`, `test.fileParallelism: false`. `src/index.ts`: `export {}` for now.

- [ ] **Step 3: Write the failing smoke test**

```ts
// functions/test/smoke.test.ts
import { db } from "./setup";
import { makeUser } from "./factories";
it("writes and reads a user through the emulator", async () => {
  const { uid } = await makeUser(db);
  const snap = await db.doc(`users/${uid}`).get();
  expect(snap.exists).toBe(true);
  expect(snap.get("emoji")).toBe("🐢");
});
```

- [ ] **Step 4: Run it to verify it fails**

Run: `cd functions && npm install && npm test`
Expected: FAIL — `./setup` / `./factories` not found.

- [ ] **Step 5: Implement `test/setup.ts` and `test/factories.ts`**

`setup.ts`: set `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080` and `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099` before `initializeApp({ projectId: "mehmmy-rewards" })`; export `db`, `auth`, `clearFirestore`; register `beforeEach(clearFirestore)`. Factories generate ids with `db.collection(..).doc().id`; `makeCrew` uses `generateInviteCode()` from Task 3 — until then, hard-code `"TEST01"` and switch in Task 3.

- [ ] **Step 6: Write a temporary deny-all `firestore.rules`** so the emulator starts: `allow read, write: if false;` for `/{document=**}`.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `npm test`
Expected: `1 passed`, emulator starts and stops cleanly.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "chore(functions): scaffold with emulator-backed vitest harness"
```

---

### Task 3: Pure helpers — types, paths, invite codes, distance, tiers, errors

**Files:**
- Create: `functions/src/types.ts`, `functions/src/lib/firestore.ts`, `functions/src/lib/inviteCode.ts`, `functions/src/lib/distance.ts`, `functions/src/lib/defaultTiers.ts`, `functions/src/lib/errors.ts`
- Test: `functions/test/inviteCode.test.ts`, `functions/test/distance.test.ts`
- Modify: `functions/test/factories.ts` (use `generateInviteCode`)

**Interfaces:**
- Produces (`types.ts`): `UserDoc`, `CrewDoc`, `MemberDoc`, `PlaceDoc`, `RideDoc`, `RequestDoc`, `RedemptionDoc`, `RouteDoc`, `ActivityDoc`, `RewardTier`, `MemberRole = "owner" | "driver"`, `RequestWhen = "now" | "morning" | "afternoon" | "tonight"`, `RedemptionStatus = "pending" | "delivered" | "rejected"`, `ActivityType = "ride" | "request" | "claim" | "redeem"`, `DistanceUnit = "auto" | "mi" | "km"`. Field names exactly as spec §3; timestamps are `Timestamp`; `meters: number`.
- Produces (`lib/firestore.ts`): `userRef(db, uid)`, `crewRef(db, crewId)`, `memberRef(db, crewId, uid)`, `membersCol(db, crewId)`, `placeRef`, `rideRef`, `requestRef`, `redemptionRef`, `routeRef(db, crewId, fromId, toId)` (doc id `${fromId}_${toId}`), `activityCol(db, crewId)`, `inviteCodeRef(db, code)`.
- Produces (`lib/inviteCode.ts`): `INVITE_ALPHABET`, `generateInviteCode(): string`, `normaliseInviteCode(raw: string): string` (trim, remove internal whitespace, upper-case), `isValidInviteCode(code: string): boolean` (length 6, all chars in alphabet).
- Produces (`lib/distance.ts`): `haversineMeters(a: {lat,lng}, b: {lat,lng}): number`, `estimateRoadMeters(a, b): number` (= `Math.round(haversine * 1.3)`), `formatDistance(meters: number, unit: "mi" | "km"): string` (`"5.3 mi"` / `"8.5 km"`, one decimal), `resolveUnit(user: Pick<UserDoc, "unit" | "locale">): "mi" | "km"`.
- Produces (`lib/defaultTiers.ts`): `DEFAULT_TIERS: RewardTier[]` with ids `t3, t5, t7, t10`.
- Produces (`lib/errors.ts`): `fail(code: FunctionsErrorCode, message: string): never`.

- [ ] **Step 1: Write the failing tests**

```ts
// inviteCode.test.ts
it("generates 6 chars from the alphabet", () => {
  for (let i = 0; i < 200; i++) {
    const c = generateInviteCode();
    expect(c).toHaveLength(6);
    expect([...c].every(ch => INVITE_ALPHABET.includes(ch))).toBe(true);
  }
});
it("normalises user input", () => {
  expect(normaliseInviteCode(" ab 12\tcd\n")).toBe("AB12CD");
});
it("rejects ambiguous characters", () => {
  expect(isValidInviteCode("AB10CD")).toBe(false);   // 1 and 0
  expect(isValidInviteCode("ABOICD")).toBe(false);   // O and I
  expect(isValidInviteCode("AB23CD")).toBe(true);
});
// distance.test.ts
it("haversine NYC→Newark ≈ 15.1 km", () => {
  const m = haversineMeters({ lat: 40.7128, lng: -74.0060 }, { lat: 40.7357, lng: -74.1724 });
  expect(m).toBeGreaterThan(14500); expect(m).toBeLessThan(15500);
});
it("road estimate is 1.3× haversine, rounded", () => {
  expect(estimateRoadMeters({ lat: 0, lng: 0 }, { lat: 0, lng: 0 })).toBe(0);
});
it("formats both units", () => {
  expect(formatDistance(8530, "mi")).toBe("5.3 mi");
  expect(formatDistance(8530, "km")).toBe("8.5 km");
});
it("resolves unit from locale when auto", () => {
  expect(resolveUnit({ unit: "auto", locale: "en-US" })).toBe("mi");
  expect(resolveUnit({ unit: "auto", locale: "tr-TR" })).toBe("km");
  expect(resolveUnit({ unit: "km", locale: "en-US" })).toBe("km");
});
```

- [ ] **Step 2: Run to verify they fail** — `npm test` → FAIL, modules not found.

- [ ] **Step 3: Implement the six modules** per Interfaces. `generateInviteCode` uses `crypto.randomInt`.

- [ ] **Step 4: Switch `makeCrew` in `test/factories.ts` to `generateInviteCode()` and `DEFAULT_TIERS`.**

- [ ] **Step 5: Run tests** — `npm test` → all pass.

- [ ] **Step 6: Commit** — `git commit -m "feat(functions): types, path helpers, invite codes, distance helpers"`

---

### Task 4: Firestore security rules

**Files:**
- Modify: `firestore.rules`
- Test: `functions/test/rules.test.ts`

**Interfaces:**
- Consumes: factories (Task 2) write fixtures through the admin SDK; the test then uses `initializeTestEnvironment` + `authenticatedContext(uid)` from `@firebase/rules-unit-testing` to exercise rules as a client.

- [ ] **Step 1: Write the failing rules tests** (one `it` per line, using `assertSucceeds` / `assertFails`)

- non-member cannot read `crews/{id}`; member can.
- driver cannot update `members/{self}.mehmmys`; owner cannot either.
- owner can create `places/*`; driver cannot.
- owner can update `crews/{id}.rewardTiers` and `.name`; owner cannot update `.inviteCode` or `.ownerUid`; driver cannot update anything.
- owner can create a ride with `createdBy == owner`, `driverUid` = a member, `meters: 8530`; driver cannot create a ride; owner cannot create a ride with `driverUid == owner`; nobody can update/delete rides.
- owner can create a request; driver can update only `{ claimedBy: self, claimedAt }` when `claimedBy` is null; a second driver cannot overwrite `claimedBy`; owner cannot create a request `byUid != self`.
- driver with balance 5 can create a redemption `{ driverUid: self, cost: 5, status: "pending" }`; cannot with `cost: 7`; cannot with `status: "delivered"`; cannot for another `driverUid`.
- owner can update a redemption `status` to `"delivered"`; driver cannot.
- nobody (client) can write `activity/*`, `routes/*`, `inviteCodes/*`, `members/*`; members can read `activity`, `routes`, `members`; `inviteCodes` unreadable.
- user can read/write own `users/{uid}`; cannot read another user's doc.

- [ ] **Step 2: Run to verify they fail** — all `assertSucceeds` cases fail under deny-all.

- [ ] **Step 3: Write `firestore.rules`**

Helper functions: `signedIn()`, `isMember(crewId)` (`exists(/databases/$(database)/documents/crews/$(crewId)/members/$(request.auth.uid))`), `isOwner(crewId)` (`get(crew).data.ownerUid == request.auth.uid`), `memberBalance(crewId, uid)`, `onlyChanged(keys)` (`request.resource.data.diff(resource.data).affectedKeys().hasOnly(keys)`). Match blocks per the test list; `rides.create` requires `request.resource.data.meters is int && > 0`, `driverUid != ownerUid`, `exists(members/driverUid)`.

- [ ] **Step 4: Run tests** — `npm test` → `rules.test.ts` all pass.

- [ ] **Step 5: Commit** — `git commit -m "feat: Firestore security rules with rules-unit tests"`

---

### Task 5: Push and route provider interfaces

**Files:**
- Create: `functions/src/lib/push.ts`, `functions/src/lib/routes.ts`
- Test: `functions/test/push.test.ts`, `functions/test/routes.test.ts`

**Interfaces:**
- Produces (`push.ts`): `type PushPayload = { title: string; body: string; data: { crewId: string; screen: "ride" | "board" | "rewards" | "activity" } }`; `interface PushSender { sendToUsers(db: Firestore, uids: string[], payload: PushPayload): Promise<void> }`; `class OutboxPushSender` (writes one doc per uid to `_pushOutbox` with `{ uid, title, body, data, ts }`); `class FcmPushSender` (reads `fcmTokens` of each uid, `messaging.sendEachForMulticast`, removes tokens whose error code is `messaging/registration-token-not-registered` or `messaging/invalid-argument` via `FieldValue.arrayRemove`); `getPushSender(): PushSender` (Outbox when `process.env.FUNCTIONS_EMULATOR === "true"` or `FIRESTORE_EMULATOR_HOST` is set, else Fcm). `FcmPushSender` constructor accepts an injectable `messaging` for tests.
- Produces (`routes.ts`): `type LatLng = { lat: number; lng: number }`; `interface RouteProvider { computeMeters(from: LatLng, to: LatLng): Promise<number> }`; `class HaversineRouteProvider` (returns `estimateRoadMeters`); `class GoogleRoutesProvider(apiKey: string)` (POST `https://routes.googleapis.com/directions/v2:computeRoutes`, `travelMode: "DRIVE"`, `routingPreference: "TRAFFIC_UNAWARE"`, field mask `routes.distanceMeters`; throws on non-200 or empty routes); `getRouteProvider(apiKey?: string): RouteProvider` (Haversine in emulator mode, Google otherwise).

- [ ] **Step 1: Write the failing tests**

```ts
// push.test.ts
it("outbox sender writes one doc per uid", async () => { /* two uids → 2 docs in _pushOutbox with the payload */ });
it("fcm sender prunes unregistered tokens", async () => {
  // user with tokens ["good","dead"]; stub messaging.sendEachForMulticast → responses [{success:true},{success:false,error:{code:"messaging/registration-token-not-registered"}}]
  // expect users/{uid}.fcmTokens toEqual(["good"])
});
it("getPushSender returns Outbox under the emulator", () => { expect(getPushSender()).toBeInstanceOf(OutboxPushSender); });
// routes.test.ts
it("haversine provider returns 1.3× great-circle", async () => { /* same coords as distance.test */ });
it("google provider parses distanceMeters", async () => { /* stub global fetch → { routes: [{ distanceMeters: 8530 }] }; expect 8530 */ });
it("google provider throws on empty routes", async () => { /* stub fetch → { routes: [] }; await expect(...).rejects.toThrow() */ });
```

- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement `push.ts` and `routes.ts`.**
- [ ] **Step 4: Run tests → pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(functions): push sender and route provider abstractions"`

---

### Task 6: Crew lifecycle logic — createCrew, joinCrew, leaveCrew, removeMember

**Files:**
- Create: `functions/src/logic/crews.ts`
- Test: `functions/test/crews.test.ts`

**Interfaces:**
- Produces: `createCrew(db, uid, input: { name: string }): Promise<{ crewId: string; inviteCode: string }>`; `joinCrew(db, uid, input: { code: string }): Promise<{ crewId: string }>`; `leaveCrew(db, uid, input: { crewId: string }): Promise<void>`; `removeMember(db, uid, input: { crewId: string; memberUid: string }): Promise<void>`. All throw `HttpsError` via `fail()`.

- [ ] **Step 1: Write the failing tests**

- `createCrew` writes crew `{ name, ownerUid, inviteCode, rewardTiers: DEFAULT_TIERS }`, owner member `{ role: "owner", mehmmys: 0, meters: 0, rides: 0 }` copied from `users/{uid}`, `inviteCodes/{code} = { crewId }`, `users/{uid}.ownedCrewId = crewId`.
- `createCrew` with `name: "  "` → `invalid-argument`; name > 40 chars → `invalid-argument`.
- `createCrew` when `ownedCrewId` already set → `failed-precondition`.
- `createCrew` retries on invite-code collision (pre-write `inviteCodes/{X}` for every value a stubbed `generateInviteCode` returns first; assert the second value is used — inject the generator as an optional 4th parameter).
- `joinCrew` with `" ab12cd "` normalises and joins; member doc has `role: "driver"` and the user's profile copy.
- `joinCrew` unknown code → `not-found`; code with `0` → `not-found`; owner joining own crew → `failed-precondition`; already a member → `already-exists`.
- `leaveCrew` as driver deletes the member doc; as owner → `failed-precondition`.
- `removeMember` by owner deletes; by driver → `permission-denied`; removing the owner → `failed-precondition`.

- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement `crews.ts`** — `createCrew` runs in a transaction (code reservation + crew + member + user); `joinCrew` reads `inviteCodes/{code}` then transaction on member doc.
- [ ] **Step 4: Run tests → pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(functions): crew create/join/leave/remove logic"`

---

### Task 7: Rides and requests — counters, activity, push

**Files:**
- Create: `functions/src/logic/rides.ts`, `functions/src/logic/requests.ts`
- Test: `functions/test/rides.test.ts`, `functions/test/requests.test.ts`

**Interfaces:**
- Consumes: `PushSender` (Task 5), path helpers, `formatDistance`, `resolveUnit`.
- Produces: `applyRideCreated(db, push: PushSender, crewId: string, rideId: string): Promise<void>`; `applyRequestCreated(db, push, crewId, requestId): Promise<void>`; `applyRequestClaimed(db, push, crewId, requestId): Promise<void>` (called only when `claimedBy` transitioned null → uid).
- Activity doc shape (all types): `{ type, ts, actorUid, actorName, actorEmoji, crewId, ...typeFields }` where ride adds `{ driverUid, driverName, fromName, toName, meters, rideId }`, request adds `{ fromName, toName, when, requestId }`, claim adds `{ requestId, driverName }`, redeem adds `{ title, cost, redemptionId }`.

- [ ] **Step 1: Write the failing tests**

- ride: owner, driver (unit `auto`, locale `en-US`), ride 8530 m → member `mehmmys 1, meters 8530, rides 1`; one activity `type: "ride"`; one `_pushOutbox` doc for the driver with body `"Mehmed gave you a Mehmmy · Home → Work · 5.3 mi"` and data `{ crewId, screen: "board" }`.
- ride with driver locale `tr-TR` → body ends `"8.5 km"`.
- ride where `driverUid` is not a member → counters untouched, ride doc gets `invalid: true`, no activity, no push.
- ride applied twice (idempotency: `rides/{id}.applied === true` after first run) → counters incremented once.
- request created → activity `type: "request"`; outbox has one doc per non-owner member (2 drivers → 2 docs, none for owner), body `"Mehmed needs a ride · Home → Work · Tonight"` (`when` label capitalised), data `screen: "ride"`.
- request claimed by driver → activity `type: "claim"`; outbox has one doc for the owner, body `"Leo's got you 🚗"`, data `screen: "activity"`.

- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement** — `applyRideCreated` uses a transaction that reads the ride and the member, bails if `applied` or driver invalid, writes counters + `applied: true`, then writes activity and sends push outside the transaction.
- [ ] **Step 4: Run tests → pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(functions): ride and request processing with activity and push"`

---

### Task 8: Redemptions

**Files:**
- Create: `functions/src/logic/redemptions.ts`
- Test: `functions/test/redemptions.test.ts`

**Interfaces:**
- Produces: `applyRedemptionCreated(db, push, crewId, redemptionId): Promise<void>`.

- [ ] **Step 1: Write the failing tests**

- balance 5, cost 3 → member `mehmmys 2`, redemption stays `pending` with `applied: true`, activity `type: "redeem"`, owner outbox body `"Leo redeemed Coffee or bakery treat (−3)"`, data `screen: "rewards"`.
- balance 2, cost 3 → `status: "rejected"`, balance unchanged, no activity, no push.
- **concurrency (Review Focus 2):** balance 5, two redemptions cost 5 created, `await Promise.all([apply(a), apply(b)])` → exactly one `pending`, one `rejected`, balance 0.
- applied twice → balance decremented once.

- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement** with a transaction over member + redemption.
- [ ] **Step 4: Run tests → pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(functions): redemption processing"`

---

### Task 9: Profile update fan-out and route computation

**Files:**
- Create: `functions/src/logic/profile.ts`, `functions/src/logic/routing.ts`
- Test: `functions/test/profile.test.ts`, `functions/test/routing.test.ts`

**Interfaces:**
- Produces: `updateProfile(db, uid, input: { displayName: string; emoji: string; color: string }): Promise<void>` — validates (name 1–30 chars trimmed, emoji 1–2 grapheme clusters, color `#RRGGBB`), writes `users/{uid}`, then updates every `members/{uid}` across crews via `db.collectionGroup("members")` filtered by `FieldPath.documentId()`-safe approach: store `uid` as a field on member docs (add to `MemberDoc` and factories: `uid: string`) and query `collectionGroup("members").where("uid", "==", uid)`.
- Produces: `computeRoute(db, provider: RouteProvider, uid, input: { crewId: string; fromPlaceId: string; toPlaceId: string }): Promise<{ meters: number; estimated: boolean }>`.

- [ ] **Step 1: Write the failing tests**

- profile: user in two crews → both member copies updated; invalid color `"red"` → `invalid-argument`.
- routing: non-member → `permission-denied`; `fromPlaceId === toPlaceId` → `invalid-argument`; unknown place → `not-found`.
- routing: first call with a provider stub returning 8530 → `{ meters: 8530, estimated: false }` and `routes/{from_to}` written with `computedAt`; second call → provider not called again (spy count 1).
- routing: provider throws → result `{ meters: estimateRoadMeters(...), estimated: true }`, cache doc has `estimated: true` and `computedAt`; a third call after setting `computedAt` 25 h in the past re-queries the provider (cache for estimated results expires after 24 h; exact results never expire).

- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement both modules.**
- [ ] **Step 4: Run tests → pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(functions): profile fan-out and cached route computation"`

---

### Task 10: Account deletion and legacy linking

**Files:**
- Create: `functions/src/logic/account.ts`
- Modify: `functions/src/logic/crews.ts` (add `linkLegacyMember`)
- Test: `functions/test/account.test.ts`, `functions/test/crews.test.ts` (append)

**Interfaces:**
- Produces: `cleanupUser(db, uid): Promise<void>` (removes memberships; if `ownedCrewId`, `db.recursiveDelete(crewRef)` and deletes `inviteCodes/{code}`; deletes `users/{uid}`); `deleteAccount(db, auth: Auth, uid): Promise<void>` (= `cleanupUser` then `auth.deleteUser(uid)`).
- Produces: `linkLegacyMember(db, uid, input: { crewId: string; stubId: string; memberUid: string }): Promise<void>` — owner only; stub is a `members/{stubId}` doc with `legacy: true` and no `uid`; moves `mehmmys`, `meters`, `rides` onto `members/{memberUid}` (adding, not replacing) and deletes the stub.

- [ ] **Step 1: Write the failing tests**

- driver in two crews deletes account → both member docs gone, `users/{uid}` gone, Auth user gone (create it first with `auth.createUser({ uid })`).
- owner with 2 drivers, 3 places, 1 ride, 1 activity deletes account → `crews/{id}` and every subcollection empty (`db.recursiveDelete` verified by listing each subcollection), `inviteCodes/{code}` gone, the code can be used by `createCrew` again (inject generator returning that code).
- `linkLegacyMember`: stub `{ legacy: true, mehmmys: 4, meters: 20000, rides: 4 }` + real member with `mehmmys 1` → real member `mehmmys 5, meters 20000, rides 4`; stub deleted; driver calling it → `permission-denied`.

- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests → pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(functions): account deletion and legacy member linking"`

---

### Task 11: Demo seed and legacy migration script

**Files:**
- Create: `functions/src/logic/demo.ts`, `functions/scripts/migrate-legacy.ts`
- Test: `functions/test/demo.test.ts`

**Interfaces:**
- Produces: `seedDemo(db, auth, input: { ownerEmail: string }): Promise<{ crewId: string; inviteCode: string; driverUids: string[] }>` — creates (or reuses by email) an Auth user, a crew named `"Demo Crew"`, three places (`Home 40.7270,-74.3174`, `Work 40.7818,-74.2691`, `EWR 40.6895,-74.1745`), three driver users (`Leo 🐶`, `Shannon 🦄`, `Manan 🐳`) with balances `2, 1, 0`, two rides and matching activity. Idempotent: running twice leaves one crew.
- Produces (`scripts/migrate-legacy.ts`, run with `tsx` against the live project by Ozzy, never in tests): reads `groups/mehmmy-crew/{friends,places,activity}`, requires `--owner-uid` and `--crew-name` args, calls `createCrew`, writes places, writes one `members/{stubId}` per friend with `{ legacy: true, displayName, emoji, color, mehmmys, meters: Math.round(miles * 1609.344), rides, role: "driver" }`, and copies activity rows as `activity` docs with `legacy: true`. Prints the invite code.

- [ ] **Step 1: Write the failing test** — `seedDemo` twice → one crew for that owner, three members besides owner, invite code valid, owner `mehmmys` 0.
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement `demo.ts`; write `migrate-legacy.ts` reusing `createCrew` and the factories' shapes (no test — it is a one-off against production; add a `--dry-run` flag that prints the plan without writing).**
- [ ] **Step 4: Run tests → pass; `npx tsx scripts/migrate-legacy.ts --dry-run --owner-uid x --crew-name y` against the emulator prints a plan and exits 0.**
- [ ] **Step 5: Commit** — `git commit -m "feat(functions): demo seed and legacy migration script"`

---

### Task 12: Wire callables and triggers, deploy config, CI

**Files:**
- Create: `functions/src/callables.ts`, `functions/src/triggers.ts`, `.github/workflows/functions-ci.yml`
- Modify: `functions/src/index.ts`, `firebase.json` (functions `runtime: nodejs22`), `README.md`

**Interfaces:**
- Produces (exported names, all `region: "us-central1"`): callables `createCrew`, `joinCrew`, `leaveCrew`, `removeMember`, `linkLegacyMember`, `computeRoute`, `updateProfile`, `deleteAccount`, `seedDemo` (guarded: `input.secret === process.env.SEED_SECRET`, `SEED_SECRET` and `GOOGLE_ROUTES_API_KEY` declared with `defineSecret`); triggers `onRideCreated` (`crews/{crewId}/rides/{rideId}`), `onRequestCreated`, `onRequestUpdated` (fires logic only when `before.claimedBy == null && after.claimedBy != null`), `onRedemptionCreated`, `onUserDeleted` (Auth v1 `user().onDelete` → `cleanupUser`).
- Each wrapper: `if (!request.auth) fail("unauthenticated", …)`, then calls the logic with `request.auth.uid`, `getPushSender()`, `getRouteProvider(apiKey)`.

- [ ] **Step 1: Write the wrappers and `index.ts` exports; set `firebase.json` functions runtime.**
- [ ] **Step 2: Verify it compiles and the emulator loads every export**

Run: `cd functions && npm run build && npx firebase emulators:exec --only functions,firestore,auth --project mehmmy-rewards "echo loaded"`
Expected: emulator log lists `✔ functions[us-central1-createCrew]` … for all 14 exports, then `loaded`.

- [ ] **Step 3: Write `.github/workflows/functions-ci.yml`** — on `pull_request` and `push` to `main`, paths `functions/**`, `firestore.rules`, `firebase.json`: `actions/setup-node@v4` (22), `actions/setup-java@v4` (temurin 21), `npm ci`, `npm run lint`, `npm run build`, `npm test` in `functions/`.
- [ ] **Step 4: Run the full suite one last time** — `npm test` → all green; `npm run lint` → clean.
- [ ] **Step 5: Update `README.md`** with: prerequisites (Node 22, Java 21), `npm test`, `npm run deploy`, secrets to set once (`firebase functions:secrets:set GOOGLE_ROUTES_API_KEY`, `SEED_SECRET`).
- [ ] **Step 6: Commit and open the PR**

```bash
git add -A && git commit -m "feat(functions): callable/trigger wiring, CI workflow"
git push -u origin phase-1-backend
gh pr create --title "Phase 0+1: repo restructure and Firebase backend" --body-file docs/superpowers/plans/2026-11-05-phase1-backend.md
```

- [ ] **Step 7: First deploy (Ozzy, after review)** — enable the Routes API in the GCP project, create a restricted API key (Routes API only), `firebase functions:secrets:set GOOGLE_ROUTES_API_KEY`, `SEED_SECRET`, then `npm run deploy`. Verify: `firebase functions:list` shows all 14 in `us-central1`.
