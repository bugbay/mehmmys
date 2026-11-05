import { db } from "./setup.js";
import { makeUser, makeCrew, makeMember } from "./factories.js";
import { updateProfile } from "../src/logic/profile.js";

const rejectsWith = (p: Promise<unknown>, code: string) => expect(p).rejects.toMatchObject({ code });

it("updates the user and every membership copy", async () => {
  const { uid } = await makeUser(db);
  const { uid: o1 } = await makeUser(db);
  const { uid: o2 } = await makeUser(db);
  const { crewId: c1 } = await makeCrew(db, o1);
  const { crewId: c2 } = await makeCrew(db, o2);
  await makeMember(db, c1, uid);
  await makeMember(db, c2, uid);
  await updateProfile(db, uid, { displayName: "  Leo ", emoji: "🐶", color: "#7DD3FC" });
  expect((await db.doc(`users/${uid}`).get()).data()).toMatchObject({ displayName: "Leo", emoji: "🐶", color: "#7DD3FC" });
  for (const c of [c1, c2]) {
    expect((await db.doc(`crews/${c}/members/${uid}`).get()).data()).toMatchObject({ displayName: "Leo", emoji: "🐶", color: "#7DD3FC" });
  }
  expect((await db.doc(`crews/${c1}/members/${o1}`).get()).get("displayName")).toBe("Test");
});

it("accepts multi-codepoint emoji as one character", async () => {
  const { uid } = await makeUser(db);
  await updateProfile(db, uid, { displayName: "Fam", emoji: "👨‍👩‍👧", color: "#000000" });
  expect((await db.doc(`users/${uid}`).get()).get("emoji")).toBe("👨‍👩‍👧");
});

it("rejects invalid input", async () => {
  const { uid } = await makeUser(db);
  await rejectsWith(updateProfile(db, uid, { displayName: "Leo", emoji: "🐶", color: "red" }), "invalid-argument");
  await rejectsWith(updateProfile(db, uid, { displayName: " ", emoji: "🐶", color: "#000000" }), "invalid-argument");
  await rejectsWith(updateProfile(db, uid, { displayName: "x".repeat(31), emoji: "🐶", color: "#000000" }), "invalid-argument");
  await rejectsWith(updateProfile(db, uid, { displayName: "Leo", emoji: "", color: "#000000" }), "invalid-argument");
  await rejectsWith(updateProfile(db, uid, { displayName: "Leo", emoji: "🐶🐶🐶", color: "#000000" }), "invalid-argument");
});

it("rejects a user without a profile", async () => {
  await rejectsWith(updateProfile(db, "ghost", { displayName: "Leo", emoji: "🐶", color: "#000000" }), "failed-precondition");
});
