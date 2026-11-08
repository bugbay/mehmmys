import { Timestamp } from "firebase-admin/firestore";
import { db } from "./setup.js";
import { makeUser, makeCrew, makeMember } from "./factories.js";
import { applyRideCreated } from "../src/logic/rides.js";
import { applyRequestCreated, applyRequestClaimed } from "../src/logic/requests.js";
import { applyRedemptionCreated } from "../src/logic/redemptions.js";
import { linkLegacyMember, joinCrew } from "../src/logic/crews.js";
import { OutboxPushSender } from "../src/lib/push.js";

const push = new OutboxPushSender();
let owner: string, leo: string, crewId: string, inviteCode: string;

beforeEach(async () => {
  ({ uid: owner } = await makeUser(db, { displayName: "Mehmed" }));
  ({ uid: leo } = await makeUser(db, { displayName: "Leo" }));
  ({ crewId, inviteCode } = await makeCrew(db, owner));
  await makeMember(db, crewId, leo, { mehmmys: 5 });
});

const doc = async (path: string) => (await db.doc(`crews/${crewId}/${path}`).get()).data();

describe("distance lives in owner-readable stats, not on members", () => {
  it("a ride adds meters to stats/{driver} and leaves the member doc without meters", async () => {
    const ref = db.collection(`crews/${crewId}/rides`).doc();
    await ref.set({ driverUid: leo, fromPlaceId: "p1", fromName: "Home", toPlaceId: "p2", toName: "Work", meters: 8530, estimated: false, ts: Timestamp.now(), createdBy: owner });
    await applyRideCreated(db, push, crewId, ref.id);
    expect(await doc(`stats/${leo}`)).toMatchObject({ meters: 8530 });
    const m = await doc(`members/${leo}`);
    expect(m).toMatchObject({ mehmmys: 6, rides: 1 });
    expect(m?.meters).toBeUndefined();
  });

  it("new members are created without meters", async () => {
    const { uid } = await makeUser(db, { displayName: "Ann" });
    await joinCrew(db, uid, { code: inviteCode });
    expect((await doc(`members/${uid}`))?.meters).toBeUndefined();
  });

  it("linking a legacy stub moves its stats too", async () => {
    await db.doc(`crews/${crewId}/members/stub1`).set({ legacy: true, role: "driver", displayName: "Old", emoji: "🐢", color: "#000000", mehmmys: 2, rides: 2 });
    await db.doc(`crews/${crewId}/stats/stub1`).set({ meters: 3000 });
    await db.doc(`crews/${crewId}/stats/${leo}`).set({ meters: 500 });
    await linkLegacyMember(db, owner, { crewId, stubId: "stub1", memberUid: leo });
    expect(await doc(`stats/${leo}`)).toMatchObject({ meters: 3500 });
    expect(await doc("stats/stub1")).toBeUndefined();
  });
});

describe("activity carries who may see it", () => {
  it("ride activity is private to the rider and driver", async () => {
    const ref = db.collection(`crews/${crewId}/rides`).doc();
    await ref.set({ driverUid: leo, fromPlaceId: "p1", fromName: "Home", toPlaceId: "p2", toName: "Work", meters: 100, estimated: false, ts: Timestamp.now(), createdBy: owner });
    await applyRideCreated(db, push, crewId, ref.id);
    expect(await doc(`activity/ride_${ref.id}`)).toMatchObject({ public: false, involved: [owner, leo] });
  });

  it("requests are public, claims involve the requester and the driver", async () => {
    const ref = db.collection(`crews/${crewId}/requests`).doc();
    await ref.set({ byUid: owner, fromName: "Home", toName: "Work", when: "now", ts: Timestamp.now(), claimedBy: leo, claimedAt: Timestamp.now() });
    await applyRequestCreated(db, push, crewId, ref.id);
    await applyRequestClaimed(db, push, crewId, ref.id);
    expect(await doc(`activity/request_${ref.id}`)).toMatchObject({ public: true });
    expect(await doc(`activity/claim_${ref.id}`)).toMatchObject({ public: false, involved: [leo, owner] });
  });

  it("redemptions are public (no route in them)", async () => {
    const ref = db.collection(`crews/${crewId}/redemptions`).doc();
    await ref.set({ driverUid: leo, tierId: "t3", title: "x", cost: 3, ts: Timestamp.now(), status: "pending" });
    await applyRedemptionCreated(db, push, crewId, ref.id);
    expect(await doc(`activity/redeem_${ref.id}`)).toMatchObject({ public: true });
  });
});
