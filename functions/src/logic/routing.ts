import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { fail } from "../lib/errors.js";
import { estimateRoadMeters } from "../lib/distance.js";
import { memberRef, placeRef, routeRef } from "../lib/firestore.js";
import type { RouteProvider } from "../lib/routes.js";
import type { PlaceDoc, RouteDoc } from "../types.js";

const ESTIMATE_TTL_MS = 24 * 3600 * 1000;

export async function computeRoute(
  db: Firestore,
  provider: RouteProvider,
  uid: string,
  input: { crewId: string; fromPlaceId: string; toPlaceId: string },
): Promise<{ meters: number; estimated: boolean }> {
  const { crewId, fromPlaceId, toPlaceId } = input ?? ({} as typeof input);
  if (!crewId || !fromPlaceId || !toPlaceId) fail("invalid-argument", "crewId, fromPlaceId and toPlaceId are required");
  if (!(await memberRef(db, crewId, uid).get()).exists) fail("permission-denied", "you are not in this crew");
  if (fromPlaceId === toPlaceId) fail("invalid-argument", "pick two different places");

  const [from, to] = await Promise.all([
    placeRef(db, crewId, fromPlaceId).get(),
    placeRef(db, crewId, toPlaceId).get(),
  ]);
  if (!from.exists || !to.exists) fail("not-found", "place not found");
  const a = from.data() as PlaceDoc;
  const b = to.data() as PlaceDoc;

  // cache is only valid while both places sit where they were when it was computed
  const cacheRef = routeRef(db, crewId, fromPlaceId, toPlaceId);
  const cached = (await cacheRef.get()).data() as (RouteDoc & Partial<Record<"fromLat" | "fromLng" | "toLat" | "toLng", number>>) | undefined;
  const samePlaces = cached && cached.fromLat === a.lat && cached.fromLng === a.lng && cached.toLat === b.lat && cached.toLng === b.lng;
  if (cached && samePlaces && (!cached.estimated || Date.now() - cached.computedAt.toMillis() < ESTIMATE_TTL_MS)) {
    return { meters: cached.meters, estimated: cached.estimated };
  }

  let result: { meters: number; estimated: boolean };
  try {
    result = { meters: Math.round(await provider.computeMeters(a, b)), estimated: false };
  } catch {
    result = { meters: Math.max(1, estimateRoadMeters(a, b)), estimated: true };
  }
  await cacheRef.set({ ...result, computedAt: Timestamp.now(), fromLat: a.lat, fromLng: a.lng, toLat: b.lat, toLng: b.lng });
  return result;
}
