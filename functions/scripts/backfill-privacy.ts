// one-off after the privacy change: move member meters into stats/{uid} and tag old activity rows
// usage: npx tsx scripts/backfill-privacy.ts [--dry-run]
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

async function main(): Promise<void> {
  const dryRun = process.argv.includes("--dry-run");
  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "mehmmy-rewards" });
  const db = getFirestore();
  const crews = await db.collection("crews").get();
  for (const crew of crews.docs) {
    const owner = crew.get("ownerUid") as string;
    const batch = db.batch();
    let moved = 0;
    let tagged = 0;
    for (const m of (await crew.ref.collection("members").get()).docs) {
      const meters = m.get("meters");
      if (typeof meters !== "number") continue;
      batch.set(crew.ref.collection("stats").doc(m.id), { meters: FieldValue.increment(meters) }, { merge: true });
      batch.update(m.ref, { meters: FieldValue.delete() });
      moved++;
    }
    for (const a of (await crew.ref.collection("activity").get()).docs) {
      if (a.get("public") !== undefined || a.get("legacy") === true) continue;
      const type = a.get("type") as string;
      const actor = a.get("actorUid") as string;
      const audience =
        type === "ride" ? { public: false, involved: [actor, a.get("driverUid") ?? actor] }
        : type === "claim" ? { public: false, involved: [actor, owner] }
        : { public: true, involved: [actor] };
      batch.update(a.ref, audience);
      tagged++;
    }
    console.log(`${crew.id} (${crew.get("name")}): ${moved} members -> stats, ${tagged} activity rows tagged`);
    if (!dryRun && moved + tagged > 0) await batch.commit();
  }
  console.log(dryRun ? "dry run: nothing written" : "done");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
