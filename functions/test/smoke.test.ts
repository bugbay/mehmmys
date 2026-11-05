import { db } from "./setup";
import { makeUser } from "./factories";

it("writes and reads a user through the emulator", async () => {
  const { uid } = await makeUser(db);
  const snap = await db.doc(`users/${uid}`).get();
  expect(snap.exists).toBe(true);
  expect(snap.get("emoji")).toBe("🐢");
});
