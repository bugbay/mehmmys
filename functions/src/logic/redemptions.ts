import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { crewRef, memberRef, redemptionRef } from "../lib/firestore.js";
import type { PushSender } from "../lib/push.js";
import { managerUids, type CrewDoc, type MemberDoc, type RedemptionDoc, type RewardTier } from "../types.js";
import { writeActivityOnce } from "./activity.js";

export async function applyRedemptionCreated(
  db: Firestore,
  push: PushSender,
  crewId: string,
  redemptionId: string,
): Promise<void> {
  const ref = redemptionRef(db, crewId, redemptionId);
  const result = await db.runTransaction(async (tx) => {
    const red = (await tx.get(ref)).data() as RedemptionDoc | undefined;
    if (!red || red.applied || red.status !== "pending") return null;
    const [crewSnap, memberSnap] = await Promise.all([
      tx.get(crewRef(db, crewId)),
      tx.get(memberRef(db, crewId, red.driverUid)),
    ]);
    const crew = crewSnap.data() as CrewDoc | undefined;
    const member = memberSnap.data() as MemberDoc | undefined;
    const tier: RewardTier | undefined = crew?.rewardTiers.find((t) => t.id === red.tierId);
    const ok = crew && member && tier && tier.cost === red.cost && member.mehmmys >= tier.cost;
    if (!ok) {
      tx.update(ref, { status: "rejected", applied: true });
      return null;
    }
    tx.update(memberSnap.ref, { mehmmys: FieldValue.increment(-tier.cost) });
    tx.update(ref, { applied: true, title: tier.title });
    return { crew, member, tier, driverUid: red.driverUid };
  });
  if (!result) return;

  const { crew, member, tier, driverUid } = result;
  const wrote = await writeActivityOnce(db, crewId, `redeem_${redemptionId}`, "redeem", driverUid, member, {
    title: tier.title,
    cost: tier.cost,
    redemptionId,
  });
  if (!wrote) return;
  await push.sendToUsers(db, managerUids(crew), {
    title: crew.name,
    body: `${member.displayName} redeemed ${tier.title} (−${tier.cost})`,
    data: { crewId, screen: "rewards" },
  });
}
