import type { Firestore } from "firebase-admin/firestore";
import type { Auth } from "firebase-admin/auth";
import { crewRef, inviteCodeRef, userRef } from "../lib/firestore.js";
import type { CrewDoc, UserDoc } from "../types.js";

export async function cleanupUser(db: Firestore, uid: string): Promise<void> {
  const user = (await userRef(db, uid).get()).data() as UserDoc | undefined;
  if (user?.ownedCrewId) {
    const ref = crewRef(db, user.ownedCrewId);
    const crew = (await ref.get()).data() as CrewDoc | undefined;
    if (crew?.ownerUid === uid) {
      await db.recursiveDelete(ref);
      if (crew.inviteCode) await inviteCodeRef(db, crew.inviteCode).delete();
    }
  }
  const memberships = await db.collectionGroup("members").where("uid", "==", uid).get();
  await Promise.all(memberships.docs.map((d) => d.ref.delete()));
  await userRef(db, uid).delete();
}

export async function deleteAccount(db: Firestore, auth: Auth, uid: string): Promise<void> {
  await cleanupUser(db, uid);
  try {
    await auth.deleteUser(uid);
  } catch (err) {
    if ((err as { code?: string }).code !== "auth/user-not-found") throw err;
  }
}
