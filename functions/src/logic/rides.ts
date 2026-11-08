import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { crewRef, memberRef, rideRef, statsRef, userRef } from "../lib/firestore.js";
import { formatDistance, resolveUnit } from "../lib/distance.js";
import type { PushSender } from "../lib/push.js";
import { isManager, type CrewDoc, type MemberDoc, type RideDoc, type UserDoc } from "../types.js";
import { writeActivityOnce } from "./activity.js";

export async function applyRideCreated(db: Firestore, push: PushSender, crewId: string, rideId: string): Promise<void> {
  const ref = rideRef(db, crewId, rideId);
  const result = await db.runTransaction(async (tx) => {
    const rideSnap = await tx.get(ref);
    const ride = rideSnap.data() as RideDoc | undefined;
    if (!ride || ride.applied || ride.invalid) return null;
    const [crewSnap, driverSnap] = await Promise.all([
      tx.get(crewRef(db, crewId)),
      tx.get(memberRef(db, crewId, ride.driverUid)),
    ]);
    const crew = crewSnap.data() as CrewDoc | undefined;
    const valid =
      crew !== undefined &&
      driverSnap.exists &&
      ride.driverUid !== ride.createdBy &&
      isManager(crew, ride.createdBy) &&
      Number.isInteger(ride.meters) &&
      ride.meters > 0;
    if (!valid) {
      tx.update(ref, { invalid: true });
      return null;
    }
    tx.update(driverSnap.ref, {
      mehmmys: FieldValue.increment(1),
      rides: FieldValue.increment(1),
    });
    tx.set(statsRef(db, crewId, ride.driverUid), { meters: FieldValue.increment(ride.meters) }, { merge: true });
    tx.update(ref, { applied: true });
    return { ride, crew: crew as CrewDoc, driver: driverSnap.data() as MemberDoc };
  });
  if (!result) return;

  const { ride, crew, driver } = result;
  const owner = (await memberRef(db, crewId, ride.createdBy).get()).data() as MemberDoc | undefined;
  const ownerName = owner?.displayName ?? "Your friend";
  const wrote = await writeActivityOnce(db, crewId, `ride_${rideId}`, "ride", ride.createdBy, owner, {
    driverUid: ride.driverUid,
    driverName: driver.displayName,
    fromName: ride.fromName,
    toName: ride.toName,
    meters: ride.meters,
    rideId,
    public: false,
    involved: [ride.createdBy, ride.driverUid],
  });
  if (!wrote) return;

  const driverUser = (await userRef(db, ride.driverUid).get()).data() as UserDoc | undefined;
  const distance = formatDistance(ride.meters, resolveUnit(driverUser ?? {}));
  await push.sendToUsers(db, [ride.driverUid], {
    title: crew.name,
    body: `${ownerName} gave you a Mehmmy · ${ride.fromName} → ${ride.toName} · ${distance}`,
    data: { crewId, screen: "board" },
  });
}
