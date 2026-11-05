import { Timestamp } from "firebase-admin/firestore";
import { db } from "./setup.js";
import { makeUser, makeCrew, makeMember } from "./factories.js";
import { applyRequestCreated, applyRequestClaimed } from "../src/logic/requests.js";
import { OutboxPushSender } from "../src/lib/push.js";

const push = new OutboxPushSender();
let ownerUid: string, leo: string, shannon: string, crewId: string, requestId: string;

beforeEach(async () => {
  ({ uid: ownerUid } = await makeUser(db, { displayName: "Mehmed", emoji: "🙋" }));
  ({ uid: leo } = await makeUser(db, { displayName: "Leo", emoji: "🐶" }));
  ({ uid: shannon } = await makeUser(db, { displayName: "Shannon", emoji: "🦄" }));
  ({ crewId } = await makeCrew(db, ownerUid, { name: "Mehmed's crew" }));
  await makeMember(db, crewId, leo);
  await makeMember(db, crewId, shannon);
  await db.doc(`crews/${crewId}/members/stub1`).set({ legacy: true, role: "driver", displayName: "Old", emoji: "🐢", color: "#000000", mehmmys: 2, meters: 0, rides: 2 });
  const ref = db.collection(`crews/${crewId}/requests`).doc();
  requestId = ref.id;
  await ref.set({ byUid: ownerUid, fromName: "Home", toName: "Work", when: "tonight", ts: Timestamp.now(), claimedBy: null, claimedAt: null });
});

const outbox = async () => (await db.collection("_pushOutbox").get()).docs.map((d) => d.data());
const activity = async () => (await db.collection(`crews/${crewId}/activity`).get()).docs.map((d) => d.data());

it("request pushes every real driver but not the owner or legacy stubs", async () => {
  await applyRequestCreated(db, push, crewId, requestId);
  const out = await outbox();
  expect(out.map((o) => o.uid).sort()).toEqual([leo, shannon].sort());
  expect(out[0]).toMatchObject({
    title: "Mehmed's crew",
    body: "Mehmed needs a ride · Home → Work · Tonight",
    data: { crewId, screen: "ride" },
  });
  const acts = await activity();
  expect(acts).toHaveLength(1);
  expect(acts[0]).toMatchObject({ type: "request", actorUid: ownerUid, actorName: "Mehmed", fromName: "Home", toName: "Work", when: "tonight", requestId });
});

it("request processing is idempotent", async () => {
  await applyRequestCreated(db, push, crewId, requestId);
  await applyRequestCreated(db, push, crewId, requestId);
  expect(await outbox()).toHaveLength(2);
  expect(await activity()).toHaveLength(1);
});

it("claim pushes the owner and records activity", async () => {
  await db.doc(`crews/${crewId}/requests/${requestId}`).update({ claimedBy: leo, claimedAt: Timestamp.now() });
  await applyRequestClaimed(db, push, crewId, requestId);
  const out = await outbox();
  expect(out).toHaveLength(1);
  expect(out[0]).toMatchObject({ uid: ownerUid, body: "Leo's got you 🚗", data: { crewId, screen: "activity" } });
  const acts = await activity();
  expect(acts).toHaveLength(1);
  expect(acts[0]).toMatchObject({ type: "claim", actorUid: leo, actorName: "Leo", driverName: "Leo", requestId });
});

it("claim on an unclaimed request does nothing", async () => {
  await applyRequestClaimed(db, push, crewId, requestId);
  expect(await outbox()).toHaveLength(0);
  expect(await activity()).toHaveLength(0);
});
