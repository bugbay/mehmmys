import { Timestamp } from "firebase-admin/firestore";
import { db } from "./setup.js";
import { makeUser, makeCrew, makeMember } from "./factories.js";
import { setCoOwner, leaveCrew, removeMember } from "../src/logic/crews.js";
import { applyRideCreated } from "../src/logic/rides.js";
import { applyRequestCreated } from "../src/logic/requests.js";
import { applyRedemptionCreated } from "../src/logic/redemptions.js";
import { cleanupUser } from "../src/logic/account.js";
import { OutboxPushSender } from "../src/lib/push.js";

const push = new OutboxPushSender();
const rejectsWith = (p: Promise<unknown>, code: string) => expect(p).rejects.toMatchObject({ code });
let founder: string, co: string, leo: string, crewId: string;

beforeEach(async () => {
  ({ uid: founder } = await makeUser(db, { displayName: "Mehmed" }));
  ({ uid: co } = await makeUser(db, { displayName: "Ozzy", emoji: "🦊" }));
  ({ uid: leo } = await makeUser(db, { displayName: "Leo", emoji: "🐶" }));
  ({ crewId } = await makeCrew(db, founder, { name: "Mehmed's crew" }));
  await makeMember(db, crewId, co);
  await makeMember(db, crewId, leo, { mehmmys: 5 });
});

const crew = async () => (await db.doc(`crews/${crewId}`).get()).data()!;
const memberOf = async (uid: string) => (await db.doc(`crews/${crewId}/members/${uid}`).get()).data();
const outbox = async () => (await db.collection("_pushOutbox").get()).docs.map((d) => d.data());

describe("setCoOwner", () => {
  it("founder promotes a member to co-owner and back", async () => {
    await setCoOwner(db, founder, { crewId, memberUid: co, coOwner: true });
    expect((await crew()).coOwnerUids).toEqual([co]);
    expect((await memberOf(co))?.role).toBe("coowner");
    await setCoOwner(db, founder, { crewId, memberUid: co, coOwner: false });
    expect((await crew()).coOwnerUids).toEqual([]);
    expect((await memberOf(co))?.role).toBe("driver");
  });

  it("only the founder can change co-owners", async () => {
    await setCoOwner(db, founder, { crewId, memberUid: co, coOwner: true });
    await rejectsWith(setCoOwner(db, co, { crewId, memberUid: leo, coOwner: true }), "permission-denied");
    await rejectsWith(setCoOwner(db, leo, { crewId, memberUid: leo, coOwner: true }), "permission-denied");
  });

  it("rejects the founder, missing members and legacy stubs", async () => {
    await db.doc(`crews/${crewId}/members/stub1`).set({ legacy: true, role: "driver", displayName: "Old", emoji: "🐢", color: "#000000", mehmmys: 0, meters: 0, rides: 0 });
    await rejectsWith(setCoOwner(db, founder, { crewId, memberUid: founder, coOwner: true }), "failed-precondition");
    await rejectsWith(setCoOwner(db, founder, { crewId, memberUid: "ghost", coOwner: true }), "not-found");
    await rejectsWith(setCoOwner(db, founder, { crewId, memberUid: "stub1", coOwner: true }), "failed-precondition");
  });

  it("caps co-owners at 5", async () => {
    for (let i = 0; i < 5; i++) {
      const { uid } = await makeUser(db);
      await makeMember(db, crewId, uid);
      await setCoOwner(db, founder, { crewId, memberUid: uid, coOwner: true });
    }
    await rejectsWith(setCoOwner(db, founder, { crewId, memberUid: co, coOwner: true }), "resource-exhausted");
  });
});

describe("co-owner lifecycle", () => {
  beforeEach(async () => { await setCoOwner(db, founder, { crewId, memberUid: co, coOwner: true }); });

  it("co-owner can leave and is dropped from coOwnerUids", async () => {
    await leaveCrew(db, co, { crewId });
    expect(await memberOf(co)).toBeUndefined();
    expect((await crew()).coOwnerUids).toEqual([]);
  });

  it("removing a co-owner drops them from coOwnerUids", async () => {
    await removeMember(db, founder, { crewId, memberUid: co });
    expect((await crew()).coOwnerUids).toEqual([]);
  });

  it("deleting a co-owner's account drops them from coOwnerUids", async () => {
    await cleanupUser(db, co);
    expect((await crew()).coOwnerUids).toEqual([]);
  });
});

describe("co-owner powers in triggers", () => {
  beforeEach(async () => { await setCoOwner(db, founder, { crewId, memberUid: co, coOwner: true }); });

  it("a ride logged by a co-owner credits the driver with the co-owner as actor", async () => {
    const ref = db.collection(`crews/${crewId}/rides`).doc();
    await ref.set({ driverUid: leo, fromPlaceId: "p1", fromName: "Home", toPlaceId: "p2", toName: "Work", meters: 1000, estimated: false, ts: Timestamp.now(), createdBy: co });
    await applyRideCreated(db, push, crewId, ref.id);
    expect((await memberOf(leo))?.mehmmys).toBe(6);
    const act = (await db.doc(`crews/${crewId}/activity/ride_${ref.id}`).get()).data();
    expect(act).toMatchObject({ actorUid: co, actorName: "Ozzy" });
    expect((await outbox())[0].body).toContain("Ozzy gave you a Mehmmy");
  });

  it("a co-owner can be credited for a ride the founder logs", async () => {
    const ref = db.collection(`crews/${crewId}/rides`).doc();
    await ref.set({ driverUid: co, fromPlaceId: "p1", fromName: "Home", toPlaceId: "p2", toName: "Work", meters: 1000, estimated: false, ts: Timestamp.now(), createdBy: founder });
    await applyRideCreated(db, push, crewId, ref.id);
    expect((await memberOf(co))?.mehmmys).toBe(1);
  });

  it("a ride by a plain driver stays invalid", async () => {
    const ref = db.collection(`crews/${crewId}/rides`).doc();
    await ref.set({ driverUid: co, fromPlaceId: "p1", fromName: "Home", toPlaceId: "p2", toName: "Work", meters: 1000, estimated: false, ts: Timestamp.now(), createdBy: leo });
    await applyRideCreated(db, push, crewId, ref.id);
    expect((await ref.get()).get("invalid")).toBe(true);
  });

  it("a co-owner's ride request reaches everyone else", async () => {
    const ref = db.collection(`crews/${crewId}/requests`).doc();
    await ref.set({ byUid: co, fromName: "Home", toName: "Work", when: "now", ts: Timestamp.now(), claimedBy: null, claimedAt: null });
    await applyRequestCreated(db, push, crewId, ref.id);
    expect((await outbox()).map((o) => o.uid).sort()).toEqual([founder, leo].sort());
  });

  it("a redemption notifies the founder and every co-owner", async () => {
    const ref = db.collection(`crews/${crewId}/redemptions`).doc();
    await ref.set({ driverUid: leo, tierId: "t3", title: "x", cost: 3, ts: Timestamp.now(), status: "pending" });
    await applyRedemptionCreated(db, push, crewId, ref.id);
    expect((await outbox()).map((o) => o.uid).sort()).toEqual([founder, co].sort());
  });
});
