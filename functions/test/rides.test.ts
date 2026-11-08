import { Timestamp } from "firebase-admin/firestore";
import { db } from "./setup.js";
import { makeUser, makeCrew, makeMember } from "./factories.js";
import { applyRideCreated } from "../src/logic/rides.js";
import { OutboxPushSender } from "../src/lib/push.js";

const push = new OutboxPushSender();
let ownerUid: string, driverUid: string, crewId: string;

beforeEach(async () => {
  ({ uid: ownerUid } = await makeUser(db, { displayName: "Mehmed", emoji: "🙋" }));
  ({ uid: driverUid } = await makeUser(db, { displayName: "Leo", emoji: "🐶", locale: "en-US" }));
  ({ crewId } = await makeCrew(db, ownerUid, { name: "Mehmed's crew" }));
  await makeMember(db, crewId, driverUid);
});

async function addRide(over: Record<string, unknown> = {}): Promise<string> {
  const ref = db.collection(`crews/${crewId}/rides`).doc();
  await ref.set({
    driverUid, fromPlaceId: "p1", fromName: "Home", toPlaceId: "p2", toName: "Work",
    meters: 8530, estimated: false, ts: Timestamp.now(), createdBy: ownerUid, ...over,
  });
  return ref.id;
}
const member = async () => (await db.doc(`crews/${crewId}/members/${driverUid}`).get()).data()!;
const outbox = async () => (await db.collection("_pushOutbox").get()).docs.map((d) => d.data());
const activity = async () => (await db.collection(`crews/${crewId}/activity`).get()).docs.map((d) => d.data());

it("credits the driver, writes activity and pushes the driver", async () => {
  const rideId = await addRide();
  await applyRideCreated(db, push, crewId, rideId);
  expect(await member()).toMatchObject({ mehmmys: 1, rides: 1 });
  expect((await db.doc(`crews/${crewId}/stats/${driverUid}`).get()).get("meters")).toBe(8530);
  const acts = await activity();
  expect(acts).toHaveLength(1);
  expect(acts[0]).toMatchObject({
    type: "ride", crewId, actorUid: ownerUid, actorName: "Mehmed", actorEmoji: "🙋",
    driverUid, driverName: "Leo", fromName: "Home", toName: "Work", meters: 8530, rideId,
  });
  const out = await outbox();
  expect(out).toHaveLength(1);
  expect(out[0]).toMatchObject({
    uid: driverUid,
    title: "Mehmed's crew",
    body: "Mehmed gave you a Mehmmy · Home → Work · 5.3 mi",
    data: { crewId, screen: "board" },
  });
  expect((await db.doc(`crews/${crewId}/rides/${rideId}`).get()).get("applied")).toBe(true);
});

it("formats distance in km for a non-US driver", async () => {
  await db.doc(`users/${driverUid}`).update({ locale: "tr-TR" });
  await applyRideCreated(db, push, crewId, await addRide());
  expect((await outbox())[0].body).toBe("Mehmed gave you a Mehmmy · Home → Work · 8.5 km");
});

it("marks a ride for a non-member invalid without crediting anyone", async () => {
  const rideId = await addRide({ driverUid: "stranger" });
  await applyRideCreated(db, push, crewId, rideId);
  expect((await db.doc(`crews/${crewId}/rides/${rideId}`).get()).get("invalid")).toBe(true);
  expect(await member()).toMatchObject({ mehmmys: 0, rides: 0 });
  expect(await activity()).toHaveLength(0);
  expect(await outbox()).toHaveLength(0);
});

it("marks a ride credited to the owner invalid", async () => {
  const rideId = await addRide({ driverUid: ownerUid });
  await applyRideCreated(db, push, crewId, rideId);
  expect((await db.doc(`crews/${crewId}/rides/${rideId}`).get()).get("invalid")).toBe(true);
  expect((await db.doc(`crews/${crewId}/members/${ownerUid}`).get()).get("mehmmys")).toBe(0);
});

it("marks a ride created by a non-owner invalid", async () => {
  const rideId = await addRide({ createdBy: driverUid });
  await applyRideCreated(db, push, crewId, rideId);
  expect((await db.doc(`crews/${crewId}/rides/${rideId}`).get()).get("invalid")).toBe(true);
  expect(await member()).toMatchObject({ mehmmys: 0 });
});

it("is idempotent", async () => {
  const rideId = await addRide();
  await applyRideCreated(db, push, crewId, rideId);
  await applyRideCreated(db, push, crewId, rideId);
  expect(await member()).toMatchObject({ mehmmys: 1, rides: 1 });
  expect((await db.doc(`crews/${crewId}/stats/${driverUid}`).get()).get("meters")).toBe(8530);
  expect(await activity()).toHaveLength(1);
  expect(await outbox()).toHaveLength(1);
});
