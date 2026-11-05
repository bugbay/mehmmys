import { Timestamp } from "firebase-admin/firestore";
import { db } from "./setup.js";
import { makeUser, makeCrew, makeMember, makePlace } from "./factories.js";
import { computeRoute } from "../src/logic/routing.js";
import { estimateRoadMeters } from "../src/lib/distance.js";
import type { RouteProvider } from "../src/lib/routes.js";

const rejectsWith = (p: Promise<unknown>, code: string) => expect(p).rejects.toMatchObject({ code });
let ownerUid: string, driverUid: string, crewId: string, home: string, work: string;
const HOME = { lat: 40.727, lng: -74.3174 };
const WORK = { lat: 40.7818, lng: -74.2691 };

beforeEach(async () => {
  ({ uid: ownerUid } = await makeUser(db));
  ({ uid: driverUid } = await makeUser(db));
  ({ crewId } = await makeCrew(db, ownerUid));
  await makeMember(db, crewId, driverUid);
  ({ placeId: home } = await makePlace(db, crewId, { name: "Home", ...HOME }));
  ({ placeId: work } = await makePlace(db, crewId, { name: "Work", ...WORK }));
});

function spyProvider(impl: () => Promise<number>): RouteProvider & { calls: number } {
  const p = { calls: 0, async computeMeters() { p.calls++; return impl(); } };
  return p;
}

it("validates membership and places", async () => {
  const p = spyProvider(async () => 1);
  await rejectsWith(computeRoute(db, p, "stranger", { crewId, fromPlaceId: home, toPlaceId: work }), "permission-denied");
  await rejectsWith(computeRoute(db, p, ownerUid, { crewId, fromPlaceId: home, toPlaceId: home }), "invalid-argument");
  await rejectsWith(computeRoute(db, p, ownerUid, { crewId, fromPlaceId: home, toPlaceId: "nope" }), "not-found");
});

it("computes once and serves the cache afterwards", async () => {
  const p = spyProvider(async () => 8530);
  expect(await computeRoute(db, p, ownerUid, { crewId, fromPlaceId: home, toPlaceId: work })).toEqual({ meters: 8530, estimated: false });
  const cached = (await db.doc(`crews/${crewId}/routes/${home}_${work}`).get()).data()!;
  expect(cached).toMatchObject({ meters: 8530, estimated: false });
  expect(cached.computedAt).toBeInstanceOf(Timestamp);
  expect(await computeRoute(db, p, driverUid, { crewId, fromPlaceId: home, toPlaceId: work })).toEqual({ meters: 8530, estimated: false });
  expect(p.calls).toBe(1);
});

it("falls back to an estimate that expires after 24 hours", async () => {
  const failing = spyProvider(async () => { throw new Error("down"); });
  const est = estimateRoadMeters(HOME, WORK);
  expect(await computeRoute(db, failing, ownerUid, { crewId, fromPlaceId: home, toPlaceId: work })).toEqual({ meters: est, estimated: true });
  expect((await db.doc(`crews/${crewId}/routes/${home}_${work}`).get()).get("estimated")).toBe(true);

  const healthy = spyProvider(async () => 9000);
  expect(await computeRoute(db, healthy, ownerUid, { crewId, fromPlaceId: home, toPlaceId: work })).toEqual({ meters: est, estimated: true });
  expect(healthy.calls).toBe(0);

  await db.doc(`crews/${crewId}/routes/${home}_${work}`).update({ computedAt: Timestamp.fromMillis(Date.now() - 25 * 3600 * 1000) });
  expect(await computeRoute(db, healthy, ownerUid, { crewId, fromPlaceId: home, toPlaceId: work })).toEqual({ meters: 9000, estimated: false });
  expect(healthy.calls).toBe(1);
});

it("recomputes when a place has moved since the route was cached", async () => {
  const p = spyProvider(async () => 8530);
  await computeRoute(db, p, ownerUid, { crewId, fromPlaceId: home, toPlaceId: work });
  await db.doc(`crews/${crewId}/places/${work}`).update({ lat: 40.8, lng: -74.1 });
  const moved = spyProvider(async () => 12000);
  expect(await computeRoute(db, moved, ownerUid, { crewId, fromPlaceId: home, toPlaceId: work })).toEqual({ meters: 12000, estimated: false });
  expect(moved.calls).toBe(1);
});
