import { Timestamp } from "firebase-admin/firestore";
import { db } from "./setup.js";
import { makeUser, makeCrew, makeMember } from "./factories.js";
import { applyRedemptionCreated } from "../src/logic/redemptions.js";
import { OutboxPushSender } from "../src/lib/push.js";

const push = new OutboxPushSender();
let ownerUid: string, leo: string, crewId: string;

beforeEach(async () => {
  ({ uid: ownerUid } = await makeUser(db, { displayName: "Mehmed" }));
  ({ uid: leo } = await makeUser(db, { displayName: "Leo", emoji: "🐶" }));
  ({ crewId } = await makeCrew(db, ownerUid, { name: "Mehmed's crew" }));
  await makeMember(db, crewId, leo, { mehmmys: 5 });
});

async function addRedemption(over: Record<string, unknown> = {}): Promise<string> {
  const ref = db.collection(`crews/${crewId}/redemptions`).doc();
  await ref.set({ driverUid: leo, tierId: "t3", title: "Coffee or bakery treat", cost: 3, ts: Timestamp.now(), status: "pending", ...over });
  return ref.id;
}
const balance = async () => (await db.doc(`crews/${crewId}/members/${leo}`).get()).get("mehmmys");
const status = async (id: string) => (await db.doc(`crews/${crewId}/redemptions/${id}`).get()).get("status");
const outbox = async () => (await db.collection("_pushOutbox").get()).docs.map((d) => d.data());
const activity = async () => (await db.collection(`crews/${crewId}/activity`).get()).docs.map((d) => d.data());

it("deducts the cost, records activity and pushes the owner", async () => {
  const id = await addRedemption();
  await applyRedemptionCreated(db, push, crewId, id);
  expect(await balance()).toBe(2);
  expect(await status(id)).toBe("pending");
  expect((await db.doc(`crews/${crewId}/redemptions/${id}`).get()).get("applied")).toBe(true);
  expect(await activity()).toEqual([expect.objectContaining({ type: "redeem", actorUid: leo, actorName: "Leo", title: "Coffee or bakery treat", cost: 3, redemptionId: id })]);
  const out = await outbox();
  expect(out).toHaveLength(1);
  expect(out[0]).toMatchObject({ uid: ownerUid, title: "Mehmed's crew", body: "Leo redeemed Coffee or bakery treat (−3)", data: { crewId, screen: "rewards" } });
});

it("rejects when the balance is too low", async () => {
  await db.doc(`crews/${crewId}/members/${leo}`).update({ mehmmys: 2 });
  const id = await addRedemption();
  await applyRedemptionCreated(db, push, crewId, id);
  expect(await status(id)).toBe("rejected");
  expect(await balance()).toBe(2);
  expect(await activity()).toHaveLength(0);
  expect(await outbox()).toHaveLength(0);
});

it("rejects a tier that does not exist or whose cost does not match", async () => {
  const unknown = await addRedemption({ tierId: "nope" });
  const cheap = await addRedemption({ tierId: "t10", cost: 1, title: "$50 gift card" });
  await applyRedemptionCreated(db, push, crewId, unknown);
  await applyRedemptionCreated(db, push, crewId, cheap);
  expect(await status(unknown)).toBe("rejected");
  expect(await status(cheap)).toBe("rejected");
  expect(await balance()).toBe(5);
});

it("uses the crew's tier title, not the client's", async () => {
  const id = await addRedemption({ title: "Free car" });
  await applyRedemptionCreated(db, push, crewId, id);
  expect((await outbox())[0].body).toBe("Leo redeemed Coffee or bakery treat (−3)");
});

it("lets exactly one of two concurrent redemptions through", async () => {
  const a = await addRedemption({ tierId: "t5", cost: 5, title: "$15 gift card" });
  const b = await addRedemption({ tierId: "t5", cost: 5, title: "$15 gift card" });
  await Promise.all([applyRedemptionCreated(db, push, crewId, a), applyRedemptionCreated(db, push, crewId, b)]);
  expect([await status(a), await status(b)].sort()).toEqual(["pending", "rejected"]);
  expect(await balance()).toBe(0);
});

it("is idempotent", async () => {
  const id = await addRedemption();
  await applyRedemptionCreated(db, push, crewId, id);
  await applyRedemptionCreated(db, push, crewId, id);
  expect(await balance()).toBe(2);
  expect(await outbox()).toHaveLength(1);
});
