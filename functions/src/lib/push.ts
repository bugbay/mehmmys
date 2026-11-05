import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { getMessaging, type Messaging } from "firebase-admin/messaging";
import type { PushScreen } from "../types.js";

export interface PushPayload {
  title: string;
  body: string;
  data: { crewId: string; screen: PushScreen };
}

export interface PushSender {
  sendToUsers(db: Firestore, uids: string[], payload: PushPayload): Promise<void>;
}

// emulator mode: record pushes so tests can assert on them
export class OutboxPushSender implements PushSender {
  async sendToUsers(db: Firestore, uids: string[], payload: PushPayload): Promise<void> {
    const batch = db.batch();
    for (const uid of uids) {
      batch.set(db.collection("_pushOutbox").doc(), { uid, ...payload, ts: Timestamp.now() });
    }
    await batch.commit();
  }
}

const DEAD_TOKEN_CODES = new Set(["messaging/registration-token-not-registered", "messaging/invalid-argument"]);

export class FcmPushSender implements PushSender {
  constructor(private readonly messaging: Pick<Messaging, "sendEachForMulticast"> = getMessaging()) {}

  async sendToUsers(db: Firestore, uids: string[], payload: PushPayload): Promise<void> {
    await Promise.all(uids.map((uid) => this.sendToUser(db, uid, payload)));
  }

  private async sendToUser(db: Firestore, uid: string, payload: PushPayload): Promise<void> {
    const ref = db.doc(`users/${uid}`);
    const tokens: string[] = (await ref.get()).get("fcmTokens") ?? [];
    if (tokens.length === 0) return;
    const res = await this.messaging.sendEachForMulticast({
      tokens,
      notification: { title: payload.title, body: payload.body },
      data: payload.data,
      apns: { payload: { aps: { sound: "default" } } },
    });
    const dead = tokens.filter((_, i) => {
      const r = res.responses[i];
      return !r.success && r.error && DEAD_TOKEN_CODES.has(r.error.code);
    });
    if (dead.length > 0) await ref.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
  }
}

export function isEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true" || Boolean(process.env.FIRESTORE_EMULATOR_HOST);
}

export function getPushSender(): PushSender {
  return isEmulator() ? new OutboxPushSender() : new FcmPushSender();
}
