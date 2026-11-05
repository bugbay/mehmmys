import { Timestamp } from "firebase-admin/firestore";
import { db } from "./setup.js";
import { makeUser, makeCrew, makeMember } from "./factories.js";

// runs only under `npm run test:e2e`, which also starts the functions emulator
const e2e = describe.skipIf(!process.env.E2E);

async function waitFor<T>(read: () => Promise<T>, ok: (v: T) => boolean, ms = 15000): Promise<T> {
  const end = Date.now() + ms;
  for (;;) {
    const v = await read();
    if (ok(v) || Date.now() > end) return v;
    await new Promise((r) => setTimeout(r, 250));
  }
}

e2e("deployed triggers", () => {
  it("a logged ride credits the driver and queues a push", async () => {
    const { uid: owner } = await makeUser(db, { displayName: "Mehmed" });
    const { uid: driver } = await makeUser(db, { displayName: "Leo" });
    const { crewId } = await makeCrew(db, owner);
    await makeMember(db, crewId, driver);
    await db.collection(`crews/${crewId}/rides`).add({
      driverUid: driver, fromPlaceId: "a", fromName: "Home", toPlaceId: "b", toName: "Work",
      meters: 8530, estimated: false, ts: Timestamp.now(), createdBy: owner,
    });
    const mehmmys = await waitFor(
      async () => (await db.doc(`crews/${crewId}/members/${driver}`).get()).get("mehmmys"),
      (v) => v === 1,
    );
    expect(mehmmys).toBe(1);
    const pushes = await waitFor(async () => (await db.collection("_pushOutbox").get()).size, (n) => n === 1);
    expect(pushes).toBe(1);
  });

  it("a claim on a request pushes the owner", async () => {
    const { uid: owner } = await makeUser(db, { displayName: "Mehmed" });
    const { uid: driver } = await makeUser(db, { displayName: "Leo" });
    const { crewId } = await makeCrew(db, owner);
    await makeMember(db, crewId, driver);
    const ref = await db.collection(`crews/${crewId}/requests`).add({
      byUid: owner, fromName: "Home", toName: "Work", when: "now", ts: Timestamp.now(), claimedBy: null, claimedAt: null,
    });
    await waitFor(async () => (await db.collection("_pushOutbox").get()).size, (n) => n === 1);
    await ref.update({ claimedBy: driver, claimedAt: Timestamp.now() });
    const bodies = await waitFor(
      async () => (await db.collection("_pushOutbox").get()).docs.map((d) => d.get("body") as string),
      (b) => b.includes("Leo's got you 🚗"),
    );
    expect(bodies).toContain("Leo's got you 🚗");
  });
});
