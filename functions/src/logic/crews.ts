import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { fail } from "../lib/errors.js";
import { DEFAULT_TIERS } from "../lib/defaultTiers.js";
import { generateInviteCode, isValidInviteCode, normaliseInviteCode } from "../lib/inviteCode.js";
import { crewRef, inviteCodeRef, memberRef, userRef } from "../lib/firestore.js";
import type { CrewDoc, MemberDoc, MemberRole, UserDoc } from "../types.js";

const MAX_CODE_ATTEMPTS = 5;

export function memberFromUser(uid: string, user: Partial<UserDoc>, role: MemberRole): MemberDoc {
  return {
    uid,
    role,
    displayName: user.displayName ?? "Friend",
    emoji: user.emoji ?? "🙂",
    color: user.color ?? "#FDBA74",
    mehmmys: 0,
    meters: 0,
    rides: 0,
    joinedAt: Timestamp.now(),
  };
}

function cleanName(raw: unknown): string {
  const name = typeof raw === "string" ? raw.trim() : "";
  if (name.length === 0 || name.length > 40) fail("invalid-argument", "crew name must be 1-40 characters");
  return name;
}

async function ownerCrew(db: Firestore, uid: string, crewId: string): Promise<CrewDoc> {
  if (typeof crewId !== "string" || crewId.length === 0) fail("invalid-argument", "crewId required");
  const crew = (await crewRef(db, crewId).get()).data() as CrewDoc | undefined;
  if (!crew) fail("not-found", "crew not found");
  if (crew.ownerUid !== uid) fail("permission-denied", "only the crew owner can do this");
  return crew;
}

export async function createCrew(
  db: Firestore,
  uid: string,
  input: { name: string },
  generate: () => string = generateInviteCode,
): Promise<{ crewId: string; inviteCode: string }> {
  const name = cleanName(input?.name);
  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
    const inviteCode = generate();
    const crewId = db.collection("crews").doc().id;
    const created = await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef(db, uid));
      const codeSnap = await tx.get(inviteCodeRef(db, inviteCode));
      if (!userSnap.exists) fail("failed-precondition", "create your profile first");
      const user = userSnap.data() as UserDoc;
      if (user.ownedCrewId) fail("failed-precondition", "you already own a crew");
      if (codeSnap.exists) return false;
      const crew: CrewDoc = { name, ownerUid: uid, inviteCode, rewardTiers: DEFAULT_TIERS, createdAt: Timestamp.now() };
      tx.set(crewRef(db, crewId), crew);
      tx.set(memberRef(db, crewId, uid), memberFromUser(uid, user, "owner"));
      tx.set(inviteCodeRef(db, inviteCode), { crewId });
      tx.update(userRef(db, uid), { ownedCrewId: crewId });
      return true;
    });
    if (created) return { crewId, inviteCode };
  }
  fail("internal", "could not allocate an invite code");
}

export async function joinCrew(db: Firestore, uid: string, input: { code: string }): Promise<{ crewId: string }> {
  const code = normaliseInviteCode(input?.code);
  if (!isValidInviteCode(code)) fail("not-found", "invite code not found");
  const codeSnap = await inviteCodeRef(db, code).get();
  if (!codeSnap.exists) fail("not-found", "invite code not found");
  const crewId = codeSnap.get("crewId") as string;
  await db.runTransaction(async (tx) => {
    const [crewSnap, memberSnap, userSnap] = await Promise.all([
      tx.get(crewRef(db, crewId)),
      tx.get(memberRef(db, crewId, uid)),
      tx.get(userRef(db, uid)),
    ]);
    if (!crewSnap.exists) fail("not-found", "invite code not found");
    if (crewSnap.get("ownerUid") === uid) fail("failed-precondition", "you own this crew");
    if (memberSnap.exists) fail("already-exists", "you are already in this crew");
    if (!userSnap.exists) fail("failed-precondition", "create your profile first");
    tx.set(memberRef(db, crewId, uid), memberFromUser(uid, userSnap.data() as UserDoc, "driver"));
  });
  return { crewId };
}

export async function leaveCrew(db: Firestore, uid: string, input: { crewId: string }): Promise<void> {
  const ref = memberRef(db, input?.crewId ?? "-", uid);
  const snap = await ref.get();
  if (!snap.exists) fail("not-found", "you are not in this crew");
  if (snap.get("role") === "owner") fail("failed-precondition", "owners delete their crew instead of leaving");
  await ref.delete();
}

export async function removeMember(
  db: Firestore,
  uid: string,
  input: { crewId: string; memberUid: string },
): Promise<void> {
  await ownerCrew(db, uid, input?.crewId);
  if (input.memberUid === uid) fail("failed-precondition", "owners cannot remove themselves");
  const ref = memberRef(db, input.crewId, input.memberUid);
  if (!(await ref.get()).exists) fail("not-found", "member not found");
  await ref.delete();
}

export async function linkLegacyMember(
  db: Firestore,
  uid: string,
  input: { crewId: string; stubId: string; memberUid: string },
): Promise<void> {
  await ownerCrew(db, uid, input?.crewId);
  const stubRef = memberRef(db, input.crewId, input.stubId);
  const realRef = memberRef(db, input.crewId, input.memberUid);
  await db.runTransaction(async (tx) => {
    const [stubSnap, realSnap] = await Promise.all([tx.get(stubRef), tx.get(realRef)]);
    if (!stubSnap.exists || stubSnap.get("legacy") !== true) fail("failed-precondition", "not a legacy member");
    if (!realSnap.exists || realSnap.get("legacy") === true) fail("not-found", "member not found");
    const stub = stubSnap.data() as MemberDoc;
    tx.update(realRef, {
      mehmmys: FieldValue.increment(stub.mehmmys ?? 0),
      meters: FieldValue.increment(stub.meters ?? 0),
      rides: FieldValue.increment(stub.rides ?? 0),
    });
    tx.delete(stubRef);
  });
}

export { ownerCrew };
