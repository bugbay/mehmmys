import { db } from "./setup.js";
import { makeUser } from "./factories.js";
import { OutboxPushSender, FcmPushSender, getPushSender, type PushPayload } from "../src/lib/push.js";

const payload: PushPayload = { title: "Mehmmy", body: "hello", data: { crewId: "c1", screen: "board" } };

it("outbox sender writes one doc per uid", async () => {
  await new OutboxPushSender().sendToUsers(db, ["a", "b"], payload);
  const snap = await db.collection("_pushOutbox").get();
  expect(snap.size).toBe(2);
  expect(snap.docs.map((d) => d.get("uid")).sort()).toEqual(["a", "b"]);
  expect(snap.docs[0].get("body")).toBe("hello");
  expect(snap.docs[0].get("data")).toEqual({ crewId: "c1", screen: "board" });
});

it("fcm sender sends to every token and prunes unregistered ones", async () => {
  const { uid } = await makeUser(db, { fcmTokens: ["good", "dead"] });
  const calls: unknown[] = [];
  const messaging = {
    sendEachForMulticast: async (msg: { tokens: string[] }) => {
      calls.push(msg);
      return {
        successCount: 1,
        failureCount: 1,
        responses: [
          { success: true },
          { success: false, error: { code: "messaging/registration-token-not-registered" } },
        ],
      };
    },
  };
  await new FcmPushSender(messaging as never).sendToUsers(db, [uid], payload);
  expect(calls).toHaveLength(1);
  expect((calls[0] as { tokens: string[] }).tokens).toEqual(["good", "dead"]);
  expect((await db.doc(`users/${uid}`).get()).get("fcmTokens")).toEqual(["good"]);
});

it("fcm sender keeps tokens on transient errors and skips users without tokens", async () => {
  const { uid } = await makeUser(db, { fcmTokens: ["t1"] });
  const { uid: empty } = await makeUser(db);
  let sent = 0;
  const messaging = {
    sendEachForMulticast: async () => {
      sent++;
      return { successCount: 0, failureCount: 1, responses: [{ success: false, error: { code: "messaging/internal-error" } }] };
    },
  };
  await new FcmPushSender(messaging as never).sendToUsers(db, [uid, empty, "missing"], payload);
  expect(sent).toBe(1);
  expect((await db.doc(`users/${uid}`).get()).get("fcmTokens")).toEqual(["t1"]);
});

it("getPushSender returns the outbox under the emulator", () => {
  expect(getPushSender()).toBeInstanceOf(OutboxPushSender);
});
