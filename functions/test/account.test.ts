import { db, auth } from "./setup.js";
import { makeUser, makeCrew, makeMember, makePlace } from "./factories.js";
import { deleteAccount, cleanupUser } from "../src/logic/account.js";
import { createCrew } from "../src/logic/crews.js";

const exists = async (path: string) => (await db.doc(path).get()).exists;

it("deletes a driver's memberships, profile and auth user", async () => {
  const { uid } = await makeUser(db);
  await auth.createUser({ uid });
  const { uid: o1 } = await makeUser(db);
  const { uid: o2 } = await makeUser(db);
  const { crewId: c1 } = await makeCrew(db, o1);
  const { crewId: c2 } = await makeCrew(db, o2);
  await makeMember(db, c1, uid);
  await makeMember(db, c2, uid);
  await deleteAccount(db, auth, uid);
  expect(await exists(`crews/${c1}/members/${uid}`)).toBe(false);
  expect(await exists(`crews/${c2}/members/${uid}`)).toBe(false);
  expect(await exists(`users/${uid}`)).toBe(false);
  expect(await exists(`crews/${c1}/members/${o1}`)).toBe(true);
  await expect(auth.getUser(uid)).rejects.toMatchObject({ code: "auth/user-not-found" });
});

it("deletes an owner's whole crew and frees the invite code", async () => {
  const { uid: owner } = await makeUser(db);
  await auth.createUser({ uid: owner });
  const { crewId, inviteCode } = await makeCrew(db, owner, { inviteCode: "QWERTY" });
  for (let i = 0; i < 2; i++) {
    const { uid } = await makeUser(db);
    await makeMember(db, crewId, uid);
  }
  for (let i = 0; i < 3; i++) await makePlace(db, crewId);
  await db.doc(`crews/${crewId}/rides/r1`).set({ meters: 1 });
  await db.doc(`crews/${crewId}/requests/q1`).set({ when: "now" });
  await db.doc(`crews/${crewId}/redemptions/x1`).set({ cost: 1 });
  await db.doc(`crews/${crewId}/routes/a_b`).set({ meters: 1 });
  await db.doc(`crews/${crewId}/activity/a1`).set({ type: "ride" });

  await deleteAccount(db, auth, owner);

  expect(await exists(`crews/${crewId}`)).toBe(false);
  for (const sub of ["members", "places", "rides", "requests", "redemptions", "routes", "activity"]) {
    expect((await db.collection(`crews/${crewId}/${sub}`).get()).size).toBe(0);
  }
  expect(await exists(`inviteCodes/${inviteCode}`)).toBe(false);
  expect(await exists(`users/${owner}`)).toBe(false);

  const { uid: next } = await makeUser(db);
  const res = await createCrew(db, next, { name: "Again" }, () => "QWERTY");
  expect(res.inviteCode).toBe("QWERTY");
});

it("still succeeds when the auth user is already gone", async () => {
  const { uid } = await makeUser(db);
  await expect(deleteAccount(db, auth, uid)).resolves.toBeUndefined();
  expect(await exists(`users/${uid}`)).toBe(false);
});

it("cleanupUser is safe for an unknown uid", async () => {
  await expect(cleanupUser(db, "nobody")).resolves.toBeUndefined();
});
