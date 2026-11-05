import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { activityCol } from "../lib/firestore.js";
import type { ActivityType, MemberDoc } from "../types.js";

const ALREADY_EXISTS = 6;

// writes activity under a deterministic id; returns false if it was already written
export async function writeActivityOnce(
  db: Firestore,
  crewId: string,
  id: string,
  type: ActivityType,
  actorUid: string,
  actor: Pick<MemberDoc, "displayName" | "emoji"> | undefined,
  fields: Record<string, unknown>,
): Promise<boolean> {
  try {
    await activityCol(db, crewId).doc(id).create({
      type,
      ts: Timestamp.now(),
      crewId,
      actorUid,
      actorName: actor?.displayName ?? "Someone",
      actorEmoji: actor?.emoji ?? "🙂",
      ...fields,
    });
    return true;
  } catch (err) {
    if ((err as { code?: number }).code === ALREADY_EXISTS) return false;
    throw err;
  }
}
