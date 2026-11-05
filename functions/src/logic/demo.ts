import { Timestamp, type Firestore } from "firebase-admin/firestore";
import type { Auth } from "firebase-admin/auth";
import { crewRef, memberRef, userRef } from "../lib/firestore.js";
import type { PushSender } from "../lib/push.js";
import { createCrew, joinCrew } from "./crews.js";
import { applyRideCreated } from "./rides.js";

const PLACES = [
  { name: "Home", lat: 40.727, lng: -74.3174 },
  { name: "Work", lat: 40.7818, lng: -74.2691 },
  { name: "EWR", lat: 40.6895, lng: -74.1745 },
];
const DRIVERS = [
  { uid: "demo-leo", displayName: "Leo", emoji: "🐶", color: "#7DD3FC", mehmmys: 2 },
  { uid: "demo-shannon", displayName: "Shannon", emoji: "🦄", color: "#C4B5FD", mehmmys: 1 },
  { uid: "demo-manan", displayName: "Manan", emoji: "🐳", color: "#86EFAC", mehmmys: 0 },
];
const silent: PushSender = { sendToUsers: async () => undefined };

async function ensureUser(db: Firestore, uid: string, profile: Record<string, unknown>): Promise<void> {
  const ref = userRef(db, uid);
  if (!(await ref.get()).exists) {
    await ref.set({ unit: "auto", locale: "en-US", fcmTokens: [], createdAt: Timestamp.now(), ...profile });
  }
}

export async function seedDemo(
  db: Firestore,
  auth: Auth,
  input: { ownerEmail: string },
): Promise<{ crewId: string; inviteCode: string; driverUids: string[] }> {
  const email = input.ownerEmail;
  const owner = await auth.getUserByEmail(email).catch(() => auth.createUser({ email, displayName: "Mehmed" }));
  await ensureUser(db, owner.uid, { displayName: "Mehmed", emoji: "🙋", color: "#FFD23F", email });
  const driverUids = DRIVERS.map((d) => d.uid);

  const existing = (await userRef(db, owner.uid).get()).get("ownedCrewId") as string | undefined;
  if (existing) {
    const inviteCode = (await crewRef(db, existing).get()).get("inviteCode") as string;
    return { crewId: existing, inviteCode, driverUids };
  }

  const { crewId, inviteCode } = await createCrew(db, owner.uid, { name: "Demo Crew" });
  const placeIds: string[] = [];
  for (const p of PLACES) {
    const ref = db.collection(`crews/${crewId}/places`).doc();
    await ref.set({ ...p, createdAt: Timestamp.now() });
    placeIds.push(ref.id);
  }
  for (const d of DRIVERS) {
    await ensureUser(db, d.uid, { displayName: d.displayName, emoji: d.emoji, color: d.color });
    await joinCrew(db, d.uid, { code: inviteCode });
  }
  const rides = [
    { driverUid: "demo-leo", from: 0, to: 1, meters: 8530 },
    { driverUid: "demo-shannon", from: 1, to: 0, meters: 8851 },
  ];
  for (const r of rides) {
    const ref = db.collection(`crews/${crewId}/rides`).doc();
    await ref.set({
      driverUid: r.driverUid,
      fromPlaceId: placeIds[r.from],
      fromName: PLACES[r.from].name,
      toPlaceId: placeIds[r.to],
      toName: PLACES[r.to].name,
      meters: r.meters,
      estimated: false,
      ts: Timestamp.now(),
      createdBy: owner.uid,
    });
    await applyRideCreated(db, silent, crewId, ref.id);
  }
  for (const d of DRIVERS) await memberRef(db, crewId, d.uid).update({ mehmmys: d.mehmmys });
  return { crewId, inviteCode, driverUids };
}
