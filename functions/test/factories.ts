import { Firestore, Timestamp } from "firebase-admin/firestore";
import { generateInviteCode } from "../src/lib/inviteCode.js";
import { DEFAULT_TIERS } from "../src/lib/defaultTiers.js";

type Doc = Record<string, unknown>;

export async function makeUser(db: Firestore, overrides: Doc = {}): Promise<{ uid: string }> {
  const { uid: given, ...fields } = overrides;
  const uid = (given as string) ?? db.collection("users").doc().id;
  await db.doc(`users/${uid}`).set({
    displayName: "Test",
    emoji: "🐢",
    color: "#FDBA74",
    email: `${uid}@example.com`,
    unit: "auto",
    locale: "en-US",
    fcmTokens: [],
    createdAt: Timestamp.now(),
    ...fields,
  });
  return { uid };
}

export async function makeCrew(
  db: Firestore,
  ownerUid: string,
  overrides: Doc = {},
): Promise<{ crewId: string; inviteCode: string }> {
  const crewId = db.collection("crews").doc().id;
  const inviteCode = (overrides.inviteCode as string) ?? generateInviteCode();
  const owner = (await db.doc(`users/${ownerUid}`).get()).data() ?? {};
  await db.doc(`crews/${crewId}`).set({
    name: "Crew",
    ownerUid,
    inviteCode,
    rewardTiers: DEFAULT_TIERS,
    createdAt: Timestamp.now(),
    ...overrides,
  });
  await db.doc(`crews/${crewId}/members/${ownerUid}`).set(memberData(ownerUid, owner, "owner"));
  await db.doc(`inviteCodes/${inviteCode}`).set({ crewId });
  await db.doc(`users/${ownerUid}`).set({ ownedCrewId: crewId }, { merge: true });
  return { crewId, inviteCode };
}

export async function makeMember(
  db: Firestore,
  crewId: string,
  uid: string,
  overrides: Doc = {},
): Promise<void> {
  const user = (await db.doc(`users/${uid}`).get()).data() ?? {};
  await db.doc(`crews/${crewId}/members/${uid}`).set({ ...memberData(uid, user, "driver"), ...overrides });
}

export async function makePlace(
  db: Firestore,
  crewId: string,
  overrides: Doc = {},
): Promise<{ placeId: string }> {
  const ref = db.collection(`crews/${crewId}/places`).doc();
  await ref.set({ name: "Home", lat: 40.727, lng: -74.3174, createdAt: Timestamp.now(), ...overrides });
  return { placeId: ref.id };
}

function memberData(uid: string, user: Doc, role: "owner" | "driver"): Doc {
  return {
    uid,
    role,
    displayName: user.displayName ?? "Test",
    emoji: user.emoji ?? "🐢",
    color: user.color ?? "#FDBA74",
    mehmmys: 0,
    meters: 0,
    rides: 0,
    joinedAt: Timestamp.now(),
  };
}
