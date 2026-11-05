// one-off: copy the legacy PWA board (groups/mehmmy-crew) into a crew owned by --owner-uid
// usage: npx tsx scripts/migrate-legacy.ts --owner-uid <uid> --crew-name "<name>" [--group mehmmy-crew] [--dry-run]
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { createCrew } from "../src/logic/crews.js";

const METERS_PER_MILE = 1609.344;

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function main(): Promise<void> {
  const ownerUid = arg("owner-uid");
  const crewName = arg("crew-name");
  const group = arg("group") ?? "mehmmy-crew";
  const dryRun = process.argv.includes("--dry-run");
  if (!ownerUid || !crewName) throw new Error("--owner-uid and --crew-name are required");

  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "mehmmy-rewards" });
  const db = getFirestore();
  const base = `groups/${group}`;
  const [friends, places, activity] = await Promise.all(
    ["friends", "places", "activity"].map((c) => db.collection(`${base}/${c}`).get()),
  );
  console.log(`legacy ${base}: ${friends.size} friends, ${places.size} places, ${activity.size} activity rows`);
  for (const f of friends.docs) {
    const d = f.data();
    console.log(`  stub legacy-${f.id}: ${d.name} ${d.emoji} mehmmys=${d.mehmmys} miles=${d.miles} rides=${d.rides}`);
  }
  if (dryRun) {
    console.log("dry run: nothing written");
    return;
  }

  const { crewId, inviteCode } = await createCrew(db, ownerUid, { name: crewName });
  const batch = db.batch();
  for (const p of places.docs) {
    const d = p.data();
    batch.set(db.doc(`crews/${crewId}/places/legacy-${p.id}`), {
      name: String(d.name).slice(0, 40), lat: d.lat, lng: d.lon ?? d.lng, createdAt: Timestamp.now(),
    });
  }
  for (const f of friends.docs) {
    const d = f.data();
    batch.set(db.doc(`crews/${crewId}/members/legacy-${f.id}`), {
      legacy: true,
      role: "driver",
      displayName: d.name,
      emoji: d.emoji,
      color: d.color,
      mehmmys: Number(d.mehmmys) || 0,
      meters: Math.round((Number(d.miles) || 0) * METERS_PER_MILE),
      rides: Number(d.rides) || 0,
      joinedAt: Timestamp.now(),
    });
  }
  for (const a of activity.docs) {
    const d = a.data();
    batch.set(db.doc(`crews/${crewId}/activity/legacy-${a.id}`), {
      legacy: true,
      type: d.type === "redeem" ? "redeem" : d.type === "request" ? "request" : "ride",
      ts: Timestamp.fromMillis(Number(d.ts) || Date.now()),
      crewId,
      actorUid: "legacy",
      actorName: d.name ?? "",
      actorEmoji: d.emoji ?? "",
      driverName: d.name ?? null,
      fromName: d.from ?? null,
      toName: d.to ?? null,
      meters: d.miles ? Math.round(Number(d.miles) * METERS_PER_MILE) : null,
      title: d.title ?? null,
      cost: d.cost ?? null,
    });
  }
  await batch.commit();
  console.log(`migrated into crew ${crewId}, invite code ${inviteCode}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
