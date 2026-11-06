import { readFileSync } from "node:fs";
import { initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, addDoc, serverTimestamp, collectionGroup, query, where, getDocs } from "firebase/firestore";
import { db, PROJECT_ID } from "./setup.js";
import { makeUser, makeCrew, makeMember, makePlace } from "./factories.js";

let env: RulesTestEnvironment;
let crewId: string;
let inviteCode: string;
let placeId: string;
const OWNER = "owner";
const DRIVER = "driver";
const DRIVER2 = "driver2";
const OUTSIDER = "outsider";

beforeAll(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080").split(":");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync("../firestore.rules", "utf8"), host, port: Number(port) },
  });
});
afterAll(async () => env.cleanup());

beforeEach(async () => {
  for (const uid of [OWNER, DRIVER, DRIVER2, OUTSIDER]) await makeUser(db, { uid });
  ({ crewId, inviteCode } = await makeCrew(db, OWNER));
  await makeMember(db, crewId, DRIVER, { mehmmys: 5 });
  await makeMember(db, crewId, DRIVER2);
  ({ placeId } = await makePlace(db, crewId));
  await db.doc(`crews/${crewId}/requests/q1`).set({ byUid: OWNER, fromName: "Home", toName: "Work", when: "now", ts: new Date(), claimedBy: null, claimedAt: null });
  await db.doc(`crews/${crewId}/redemptions/r1`).set({ driverUid: DRIVER, tierId: "t3", title: "Coffee", cost: 3, ts: new Date(), status: "pending" });
  await db.doc(`crews/${crewId}/rides/ride1`).set({ driverUid: DRIVER, meters: 100 });
  await db.doc(`crews/${crewId}/activity/a1`).set({ type: "ride" });
  await db.doc(`crews/${crewId}/routes/a_b`).set({ meters: 100 });
});

const as = (uid: string) => env.authenticatedContext(uid).firestore();
const c = (uid: string, path = "") => doc(as(uid), `crews/${crewId}${path}`);
const ride = (over: Record<string, unknown> = {}) => ({
  driverUid: DRIVER, fromPlaceId: placeId, fromName: "Home", toPlaceId: "p2", toName: "Work",
  meters: 8530, estimated: false, ts: serverTimestamp(), createdBy: OWNER, ...over,
});
const redemption = (over: Record<string, unknown> = {}) => ({
  driverUid: DRIVER, tierId: "t5", title: "$15 gift card", cost: 5, ts: serverTimestamp(), status: "pending", ...over,
});

describe("crew", () => {
  it("non-member cannot read crew", async () => { await assertFails(getDoc(c(OUTSIDER))); });
  it("member can read crew", async () => { await assertSucceeds(getDoc(c(DRIVER))); });
  it("unauthenticated cannot read crew", async () => {
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), `crews/${crewId}`)));
  });
  it("owner can update name and rewardTiers", async () => {
    await assertSucceeds(updateDoc(c(OWNER), { name: "New", rewardTiers: [{ id: "t1", cost: 1, icon: "☕", title: "x", subtitle: "" }] }));
  });
  it("owner cannot update inviteCode or ownerUid", async () => {
    await assertFails(updateDoc(c(OWNER), { inviteCode: "ZZZZZZ" }));
    await assertFails(updateDoc(c(OWNER), { ownerUid: DRIVER }));
  });
  it("driver cannot update crew", async () => { await assertFails(updateDoc(c(DRIVER), { name: "Mine" })); });
  it("nobody can create or delete crews", async () => {
    await assertFails(setDoc(doc(as(OUTSIDER), "crews/new"), { name: "x", ownerUid: OUTSIDER }));
    await assertFails(deleteDoc(c(OWNER)));
  });
});

describe("members", () => {
  it("members can read members", async () => { await assertSucceeds(getDoc(c(DRIVER, `/members/${DRIVER2}`))); });
  it("driver cannot change own balance", async () => { await assertFails(updateDoc(c(DRIVER, `/members/${DRIVER}`), { mehmmys: 99 })); });
  it("owner cannot change a balance", async () => { await assertFails(updateDoc(c(OWNER, `/members/${DRIVER}`), { mehmmys: 99 })); });
  it("nobody can add a member directly", async () => {
    await assertFails(setDoc(c(OUTSIDER, `/members/${OUTSIDER}`), { role: "driver" }));
    await assertFails(setDoc(c(OWNER, `/members/${OUTSIDER}`), { role: "driver" }));
  });
});

describe("places", () => {
  const place = { name: "Gym", lat: 40.7, lng: -74.1, createdAt: serverTimestamp() };
  it("owner can create a place", async () => { await assertSucceeds(addDoc(collection(as(OWNER), `crews/${crewId}/places`), place)); });
  it("driver cannot create a place", async () => { await assertFails(addDoc(collection(as(DRIVER), `crews/${crewId}/places`), place)); });
  it("owner cannot create a place with invalid coordinates", async () => {
    await assertFails(addDoc(collection(as(OWNER), `crews/${crewId}/places`), { ...place, lat: 123 }));
  });
  it("owner can delete a place, driver cannot", async () => {
    await assertFails(deleteDoc(c(DRIVER, `/places/${placeId}`)));
    await assertSucceeds(deleteDoc(c(OWNER, `/places/${placeId}`)));
  });
});

describe("rides", () => {
  const col = (uid: string) => collection(as(uid), `crews/${crewId}/rides`);
  it("owner can log a ride for a member driver", async () => { await assertSucceeds(addDoc(col(OWNER), ride())); });
  it("driver cannot log a ride", async () => { await assertFails(addDoc(col(DRIVER), ride({ createdBy: DRIVER, driverUid: DRIVER2 }))); });
  it("owner cannot log a ride for themselves", async () => { await assertFails(addDoc(col(OWNER), ride({ driverUid: OWNER }))); });
  it("owner cannot log a ride for a non-member", async () => { await assertFails(addDoc(col(OWNER), ride({ driverUid: OUTSIDER }))); });
  it("owner cannot log a ride with zero or fractional meters", async () => {
    await assertFails(addDoc(col(OWNER), ride({ meters: 0 })));
    await assertFails(addDoc(col(OWNER), ride({ meters: 10.5 })));
  });
  it("owner cannot pre-mark a ride as applied", async () => { await assertFails(addDoc(col(OWNER), ride({ applied: true }))); });
  it("nobody can update or delete rides", async () => {
    await assertFails(updateDoc(c(OWNER, "/rides/ride1"), { meters: 1 }));
    await assertFails(deleteDoc(c(OWNER, "/rides/ride1")));
  });
});

describe("requests", () => {
  const req = { byUid: OWNER, fromName: "Home", toName: "Work", when: "tonight", ts: serverTimestamp(), claimedBy: null, claimedAt: null };
  it("owner can create a request", async () => { await assertSucceeds(addDoc(collection(as(OWNER), `crews/${crewId}/requests`), req)); });
  it("owner cannot create a request for someone else", async () => {
    await assertFails(addDoc(collection(as(OWNER), `crews/${crewId}/requests`), { ...req, byUid: DRIVER }));
  });
  it("driver cannot create a request", async () => {
    await assertFails(addDoc(collection(as(DRIVER), `crews/${crewId}/requests`), { ...req, byUid: DRIVER }));
  });
  it("driver can claim an open request", async () => {
    await assertSucceeds(updateDoc(c(DRIVER, "/requests/q1"), { claimedBy: DRIVER, claimedAt: serverTimestamp() }));
  });
  it("driver cannot claim for someone else or touch other fields", async () => {
    await assertFails(updateDoc(c(DRIVER, "/requests/q1"), { claimedBy: DRIVER2, claimedAt: serverTimestamp() }));
    await assertFails(updateDoc(c(DRIVER, "/requests/q1"), { claimedBy: DRIVER, claimedAt: serverTimestamp(), toName: "Bar" }));
  });
  it("second driver cannot overwrite a claim", async () => {
    await db.doc(`crews/${crewId}/requests/q1`).update({ claimedBy: DRIVER, claimedAt: new Date() });
    await assertFails(updateDoc(c(DRIVER2, "/requests/q1"), { claimedBy: DRIVER2, claimedAt: serverTimestamp() }));
  });
  it("outsider cannot claim", async () => {
    await assertFails(updateDoc(c(OUTSIDER, "/requests/q1"), { claimedBy: OUTSIDER, claimedAt: serverTimestamp() }));
  });
});

describe("redemptions", () => {
  const col = (uid: string) => collection(as(uid), `crews/${crewId}/redemptions`);
  it("driver with balance 5 can redeem cost 5", async () => { await assertSucceeds(addDoc(col(DRIVER), redemption())); });
  it("driver cannot redeem above balance", async () => { await assertFails(addDoc(col(DRIVER), redemption({ cost: 7 }))); });
  it("driver cannot create a delivered redemption", async () => { await assertFails(addDoc(col(DRIVER), redemption({ status: "delivered" }))); });
  it("driver cannot redeem for another driver", async () => { await assertFails(addDoc(col(DRIVER2), redemption())); });
  it("owner can mark an applied redemption delivered, driver cannot", async () => {
    await db.doc(`crews/${crewId}/redemptions/r1`).update({ applied: true });
    await assertFails(updateDoc(c(DRIVER, "/redemptions/r1"), { status: "delivered" }));
    await assertSucceeds(updateDoc(c(OWNER, "/redemptions/r1"), { status: "delivered" }));
  });
  it("owner cannot mark delivered before the balance is charged", async () => {
    await assertFails(updateDoc(c(OWNER, "/redemptions/r1"), { status: "delivered" }));
  });
});

describe("function-owned collections", () => {
  it("members can read activity and routes", async () => {
    await assertSucceeds(getDoc(c(DRIVER, "/activity/a1")));
    await assertSucceeds(getDoc(c(DRIVER, "/routes/a_b")));
  });
  it("outsider cannot read activity", async () => { await assertFails(getDoc(c(OUTSIDER, "/activity/a1"))); });
  it("clients cannot write activity, routes or invite codes", async () => {
    await assertFails(setDoc(c(OWNER, "/activity/x"), { type: "ride" }));
    await assertFails(setDoc(c(OWNER, "/routes/x_y"), { meters: 1 }));
    await assertFails(setDoc(doc(as(OWNER), "inviteCodes/AAAAAA"), { crewId }));
  });
  it("invite codes are not readable", async () => { await assertFails(getDoc(doc(as(DRIVER), `inviteCodes/${inviteCode}`))); });
});

describe("users", () => {
  it("user can read and write own profile", async () => {
    await assertSucceeds(getDoc(doc(as(DRIVER), `users/${DRIVER}`)));
    await assertSucceeds(updateDoc(doc(as(DRIVER), `users/${DRIVER}`), { fcmTokens: ["tok"] }));
  });
  it("user cannot read another user's profile", async () => { await assertFails(getDoc(doc(as(DRIVER), `users/${OWNER}`))); });
  it("user cannot set or clear ownedCrewId", async () => {
    await assertFails(updateDoc(doc(as(OWNER), `users/${OWNER}`), { ownedCrewId: null }));
    await assertFails(updateDoc(doc(as(DRIVER), `users/${DRIVER}`), { ownedCrewId: crewId }));
  });
});

describe("membership lookup", () => {
  it("a user can list their own memberships across crews", async () => {
    const q = query(collectionGroup(as(DRIVER), "members"), where("uid", "==", DRIVER));
    const snap = await assertSucceeds(getDocs(q));
    expect(snap.docs.map((d) => d.ref.parent.parent?.id)).toEqual([crewId]);
  });
  it("a user cannot list someone else's memberships", async () => {
    await assertFails(getDocs(query(collectionGroup(as(OUTSIDER), "members"), where("uid", "==", DRIVER))));
  });
});

describe("profile validation", () => {
  const me = () => doc(as(DRIVER), `users/${DRIVER}`);
  it("accepts valid profile, unit, locale and token updates", async () => {
    await assertSucceeds(updateDoc(me(), { displayName: "Leo", emoji: "🐶", color: "#7DD3FC", unit: "km", locale: "en_US", fcmTokens: ["a", "b"] }));
  });
  it("rejects an oversized name, bad color, bad unit or non-list tokens", async () => {
    await assertFails(updateDoc(me(), { displayName: "x".repeat(31) }));
    await assertFails(updateDoc(me(), { color: "red" }));
    await assertFails(updateDoc(me(), { unit: "furlongs" }));
    await assertFails(updateDoc(me(), { fcmTokens: "tok" }));
    await assertFails(updateDoc(me(), { fcmTokens: Array.from({ length: 11 }, (_, i) => `t${i}`) }));
  });
  it("rejects unknown fields", async () => {
    await assertFails(updateDoc(me(), { isAdmin: true }));
  });
  it("a new user can create a valid profile", async () => {
    const ctx = env.authenticatedContext("newbie").firestore();
    await assertSucceeds(setDoc(doc(ctx, "users/newbie"), {
      displayName: "New", emoji: "🐸", color: "#86EFAC", unit: "auto", locale: "en_US", fcmTokens: [], createdAt: serverTimestamp(),
    }));
  });
});

describe("legacy PWA board", () => {
  it("signed-in (anonymous) users keep read/write on groups/**", async () => {
    const anon = env.authenticatedContext("anon-device").firestore();
    await assertSucceeds(setDoc(doc(anon, "groups/mehmmy-crew/friends/1"), { name: "Leo", mehmmys: 1 }));
    await assertSucceeds(getDoc(doc(anon, "groups/mehmmy-crew/friends/1")));
  });
  it("unauthenticated clients cannot touch groups/**", async () => {
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "groups/mehmmy-crew/friends/1")));
  });
});

describe("co-owners", () => {
  // driver2 is promoted to co-owner the way setCoOwner does it
  beforeEach(async () => {
    await db.doc(`crews/${crewId}`).update({ coOwnerUids: [DRIVER2] });
    await db.doc(`crews/${crewId}/members/${DRIVER2}`).update({ role: "coowner" });
  });
  const place = { name: "Gym", lat: 40.7, lng: -74.1, createdAt: serverTimestamp() };
  const req = { byUid: DRIVER2, fromName: "Home", toName: "Work", when: "now", ts: serverTimestamp() };

  it("co-owner can rename the crew and edit tiers", async () => {
    await assertSucceeds(updateDoc(c(DRIVER2), { name: "Ours" }));
  });
  it("co-owner cannot change the co-owner list", async () => {
    await assertFails(updateDoc(c(DRIVER2), { coOwnerUids: [DRIVER2, DRIVER] }));
    await assertFails(updateDoc(c(OWNER), { coOwnerUids: [DRIVER] }));
  });
  it("co-owner can add and delete places", async () => {
    await assertSucceeds(addDoc(collection(as(DRIVER2), `crews/${crewId}/places`), place));
    await assertSucceeds(deleteDoc(c(DRIVER2, `/places/${placeId}`)));
  });
  it("co-owner can log a ride for another member but not for themselves", async () => {
    const col = collection(as(DRIVER2), `crews/${crewId}/rides`);
    await assertSucceeds(addDoc(col, ride({ createdBy: DRIVER2 })));
    await assertSucceeds(addDoc(col, ride({ createdBy: DRIVER2, driverUid: OWNER })));
    await assertFails(addDoc(col, ride({ createdBy: DRIVER2, driverUid: DRIVER2 })));
  });
  it("founder can log a ride crediting a co-owner", async () => {
    await assertSucceeds(addDoc(collection(as(OWNER), `crews/${crewId}/rides`), ride({ driverUid: DRIVER2 })));
  });
  it("co-owner can create a request; others (incl. founder) can claim it, the requester cannot", async () => {
    await assertSucceeds(setDoc(c(DRIVER2, "/requests/q2"), req));
    await assertFails(updateDoc(c(DRIVER2, "/requests/q2"), { claimedBy: DRIVER2, claimedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(c(OWNER, "/requests/q2"), { claimedBy: OWNER, claimedAt: serverTimestamp() }));
  });
  it("co-owner can claim the founder's request", async () => {
    await assertSucceeds(updateDoc(c(DRIVER2, "/requests/q1"), { claimedBy: DRIVER2, claimedAt: serverTimestamp() }));
  });
  it("co-owner can mark an applied redemption delivered", async () => {
    await db.doc(`crews/${crewId}/redemptions/r1`).update({ applied: true });
    await assertSucceeds(updateDoc(c(DRIVER2, "/redemptions/r1"), { status: "delivered" }));
  });
  it("plain drivers still cannot manage", async () => {
    await assertFails(updateDoc(c(DRIVER), { name: "Mine" }));
    await assertFails(addDoc(collection(as(DRIVER), `crews/${crewId}/places`), place));
  });
});
